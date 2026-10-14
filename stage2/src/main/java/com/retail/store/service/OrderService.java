package com.retail.store.service;

import com.retail.store.dto.OrderRequest;
import com.retail.store.entity.*;
import com.retail.store.exception.BusinessRuleException;
import com.retail.store.exception.NotFoundException;
import com.retail.store.exception.TransactionException;
import com.retail.store.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final ProductRepository productRepository;
    private final InventoryRepository inventoryRepository;
    private final MemberRepository memberRepository;

    public List<Order> getAllOrders() {
        return orderRepository.findAllWithRelations();
    }

    public Map<String, Object> getOrderDetail(String orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new NotFoundException("订单不存在"));
        List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
        Map<String, Object> result = new HashMap<>();
        result.put("order", order);
        result.put("items", items);
        return result;
    }

    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> createOrder(OrderRequest request, String cashierId) {
        try {
            // 1. 校验商品并计算金额
            BigDecimal totalAmount = BigDecimal.ZERO;
            List<OrderItem> items = new ArrayList<>();

            for (OrderRequest.OrderItemRequest itemReq : request.getItems()) {
                Product product = productRepository.findById(itemReq.getProductId())
                        .orElseThrow(() -> new NotFoundException("商品 " + itemReq.getProductId() + " 不存在"));

                // 2. 校验库存
                Inventory inv = inventoryRepository.findByProductProductId(itemReq.getProductId())
                        .orElseThrow(() -> new NotFoundException("商品 " + itemReq.getProductId() + " 无库存记录"));

                if (inv.getQuantity() < itemReq.getQuantity()) {
                    throw new BusinessRuleException("商品 " + product.getProductName() + " 库存不足");
                }

                BigDecimal subtotal = product.getSalePrice().multiply(BigDecimal.valueOf(itemReq.getQuantity()));
                totalAmount = totalAmount.add(subtotal);

                OrderItem item = new OrderItem();
                item.setProductId(product.getProductId());
                item.setQuantity(itemReq.getQuantity());
                item.setUnitPrice(product.getSalePrice());
                item.setSubtotal(subtotal);
                items.add(item);
            }

            // 3. 生成订单号
            String orderId = generateOrderId();

            // 4. 写入订单主表
            Order order = new Order();
            order.setOrderId(orderId);
            order.setOrderTime(LocalDateTime.now());
            order.setTotalAmount(totalAmount);
            order.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "现金");
            order.setOrderStatus("已支付");
            order.setRemark(request.getRemark());

            if (request.getMemberId() != null) {
                Member member = memberRepository.findById(request.getMemberId())
                        .orElseThrow(() -> new NotFoundException("会员不存在"));
                order.setMemberId(request.getMemberId());
            }

            if (cashierId != null) {
                order.setCashierId(cashierId);
            }

            orderRepository.save(order);

            // 5. 写入订单明细
            for (OrderItem item : items) {
                item.setOrderId(orderId);
                orderItemRepository.save(item);
            }

            // 6. 扣减库存
            for (OrderRequest.OrderItemRequest itemReq : request.getItems()) {
                int updated = inventoryRepository.deductStock(itemReq.getProductId(), itemReq.getQuantity());
                if (updated == 0) {
                    throw new BusinessRuleException("商品 " + itemReq.getProductId() + " 扣减库存失败");
                }
            }

            // 7. 更新会员积分
            if (request.getMemberId() != null) {
                int points = totalAmount.intValue();
                memberRepository.addPoints(request.getMemberId(), points);
            }

            log.info("创建订单成功: {} 金额={} 商品数={}", orderId, totalAmount, items.size());

            Map<String, Object> result = new HashMap<>();
            result.put("orderId", orderId);
            result.put("totalAmount", totalAmount);
            result.put("itemCount", items.size());
            result.put("message", "订单创建成功");
            return result;

        } catch (NotFoundException | BusinessRuleException e) {
            log.warn("订单创建业务异常: {}", e.getMessage());
            throw e;
        } catch (Exception e) {
            log.error("订单创建事务失败: {}", e.getMessage(), e);
            throw new TransactionException("订单创建事务失败: " + e.getMessage());
        }
    }

    private String generateOrderId() {
        String dateStr = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String prefix = "ORD" + dateStr + "%";
        Integer maxSeq = orderRepository.findMaxSeqByPrefix(prefix);
        int seq = (maxSeq != null ? maxSeq : 0) + 1;
        return "ORD" + dateStr + String.format("%04d", seq);
    }

    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> cancelOrder(String orderId) {
        try {
            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new NotFoundException("订单不存在"));

            if ("已取消".equals(order.getOrderStatus()) || "已退款".equals(order.getOrderStatus())) {
                throw new BusinessRuleException("订单已取消/退款，不可重复取消");
            }

            // 1. 修改订单状态
            order.setOrderStatus("已取消");
            orderRepository.save(order);

            // 2. 恢复库存
            List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
            for (OrderItem item : items) {
                inventoryRepository.deductStock(item.getProductId(), -item.getQuantity());
            }

            // 3. 扣减会员积分
            if (order.getMemberId() != null) {
                int points = order.getTotalAmount().intValue();
                memberRepository.addPoints(order.getMemberId(), -points);
            }

            log.info("取消订单成功: {} 恢复库存{}项", orderId, items.size());
            Map<String, Object> result = new HashMap<>();
            result.put("orderId", orderId);
            result.put("status", "已取消");
            result.put("restoredItems", items.size());
            return result;
        } catch (NotFoundException | BusinessRuleException e) {
            log.warn("取消订单业务异常: {}", e.getMessage());
            throw e;
        } catch (Exception e) {
            log.error("取消订单事务失败: {}", e.getMessage(), e);
            throw new TransactionException("取消订单事务失败: " + e.getMessage());
        }
    }
}
