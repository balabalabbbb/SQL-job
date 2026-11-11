package com.retail.store.service;

import com.retail.store.dto.OrderRequest;
import com.retail.store.entity.*;
import com.retail.store.exception.BusinessRuleException;
import com.retail.store.exception.NotFoundException;
import com.retail.store.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.math.BigDecimal;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final ProductRepository productRepository;
    private final InventoryRepository inventoryRepository;
    private final MemberRepository memberRepository;
    private final DatabaseProgramDao programDao;

    /**
     * 创建订单（折扣规则由数据库函数实现，Java 只传参）。
     * 输入：OrderRequest（商品行/支付方式/会员[可空]/备注）、收银员编号
     * 处理：校验 → 数据库函数算折扣 → 写订单(折扣字段) → 写明细(原价) → 扣库存 → 积分
     * 输出：订单详情 Map
     */
    @Transactional
    public Map<String, Object> createOrder(OrderRequest request, String cashierId) {
        if (request.getItems() == null || request.getItems().isEmpty()) {
            throw new BusinessRuleException("订单商品不能为空");
        }

        // 1. 校验商品与库存，计算折前金额
        BigDecimal originalAmount = BigDecimal.ZERO;
        List<ValidatedLine> lines = new ArrayList<>();
        for (OrderRequest.OrderItemRequest item : request.getItems()) {
            if (item.getQuantity() <= 0) {
                throw new BusinessRuleException("商品数量必须大于0");
            }
            Product product = productRepository.findById(item.getProductId())
                    .orElseThrow(() -> new NotFoundException("商品不存在: " + item.getProductId()));
            if (!"在售".equals(product.getStatus())) {
                throw new BusinessRuleException("商品已下架: " + product.getProductName());
            }
            Inventory inventory = inventoryRepository.findByProductProductId(item.getProductId())
                    .orElseThrow(() -> new BusinessRuleException("商品库存记录不存在: " + item.getProductId()));
            if (inventory.getQuantity() < item.getQuantity()) {
                throw new BusinessRuleException("商品库存不足: " + product.getProductName());
            }
            BigDecimal lineSubtotal = product.getSalePrice()
                    .multiply(BigDecimal.valueOf(item.getQuantity()));
            originalAmount = originalAmount.add(lineSubtotal);
            lines.add(new ValidatedLine(product, inventory, item.getQuantity()));
        }

        // 2. 调用数据库函数计算折扣率与折扣金额（会员可为空=散客）
        String memberId = request.getMemberId();
        BigDecimal rate = programDao.discountRate(memberId, originalAmount);
        if (rate == null) {
            rate = BigDecimal.ONE;   // 函数对非法会员返回 NULL，按无折扣处理
        }
        BigDecimal discountAmount = programDao.discountAmount(originalAmount, rate);
        if (discountAmount == null) {
            discountAmount = BigDecimal.ZERO;
        }
        BigDecimal totalAmount = originalAmount.subtract(discountAmount);

        // 3. 生成订单并写入折扣字段（total_amount 为折后应付）
        String orderId = generateOrderId();
        Order order = new Order();
        order.setOrderId(orderId);
        order.setOrderTime(LocalDateTime.now());
        order.setMemberId(memberId);
        order.setCashierId(cashierId);
        order.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "现金");
        order.setOrderStatus("已支付");
        order.setRemark(request.getRemark());
        order.setDiscountRate(rate);
        order.setDiscountAmount(discountAmount);
        order.setTotalAmount(totalAmount);
        orderRepository.save(order);

        // 4. 写订单明细（原价快照）并扣减库存
        for (ValidatedLine line : lines) {
            Product p = line.product();
            int qty = line.quantity();

            OrderItem oi = new OrderItem();
            oi.setOrderId(orderId);
            oi.setProductId(p.getProductId());
            oi.setUnitPrice(p.getSalePrice());
            oi.setQuantity(qty);
            oi.setSubtotal(p.getSalePrice().multiply(BigDecimal.valueOf(qty)));
            orderItemRepository.save(oi);

            Inventory inv = line.inventory();
            inv.setQuantity(inv.getQuantity() - qty);
            inv.setLastUpdated(LocalDateTime.now());
            inventoryRepository.save(inv);
        }

        // 5. 会员积分按折后实付金额累计
        if (memberId != null) {
            memberRepository.findById(memberId).ifPresent(m -> {
                m.setPointsBalance(m.getPointsBalance() + totalAmount.intValue());
                memberRepository.save(m);
            });
        }

        log.info("订单创建成功: {} 折前{} 折扣{} 实付{}", orderId, originalAmount, discountAmount, totalAmount);
        return getOrderDetail(orderId);
    }

    /** 校验通过的商品行 */
    private record ValidatedLine(Product product, Inventory inventory, int quantity) {}

    @Transactional
    public Map<String, Object> cancelOrder(String orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new NotFoundException("订单不存在: " + orderId));

        if ("已取消".equals(order.getOrderStatus())) {
            throw new BusinessRuleException("订单已取消，请勿重复操作");
        }
        if ("已退款".equals(order.getOrderStatus())) {
            throw new BusinessRuleException("订单已退款，无法取消");
        }

        List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
        for (OrderItem item : items) {
            Inventory inventory = inventoryRepository.findByProductProductId(item.getProductId())
                    .orElseThrow(() -> new BusinessRuleException("库存记录不存在: " + item.getProductId()));
            inventory.setQuantity(inventory.getQuantity() + item.getQuantity());
            inventory.setLastUpdated(LocalDateTime.now());
            inventoryRepository.save(inventory);
        }

        if (order.getMemberId() != null) {
            memberRepository.findById(order.getMemberId()).ifPresent(m -> {
                int pointsToDeduct = order.getTotalAmount().intValue();
                m.setPointsBalance(Math.max(0, m.getPointsBalance() - pointsToDeduct));
                memberRepository.save(m);
            });
        }

        order.setOrderStatus("已取消");
        orderRepository.save(order);
        log.info("订单取消成功: {}", orderId);
        return getOrderDetail(orderId);
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAllWithRelations();
    }

    public Map<String, Object> getOrderDetail(String orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new NotFoundException("订单不存在: " + orderId));

        List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
        List<Map<String, Object>> itemDetails = new ArrayList<>();

        for (OrderItem item : items) {
            Map<String, Object> detail = new HashMap<>();
            detail.put("item_id", item.getItemId());
            detail.put("product_id", item.getProductId());
            Product product = productRepository.findById(item.getProductId()).orElse(null);
            detail.put("product_name", product != null ? product.getProductName() : "未知商品");
            detail.put("unit_price", item.getUnitPrice());
            detail.put("quantity", item.getQuantity());
            detail.put("subtotal", item.getSubtotal());
            itemDetails.add(detail);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("order", order);
        result.put("items", itemDetails);
        return result;
    }

    /**
     * 生成新格式订单号 ORD+4位序号：
     * 取当前新格式订单的最大序号加 1，而非 count+1，
     * 这样即使删除过订单也不会与已有订单号冲突（避免主键重复）。
     */
    private String generateOrderId() {
        Integer maxSeq = orderRepository.findMaxShortSeq();
        int next = (maxSeq == null ? 0 : maxSeq) + 1;
        return String.format("ORD%04d", next);
    }
}
