package com.retail.store.service;

import com.retail.store.dto.RestockSuggestion;
import com.retail.store.entity.Inventory;
import com.retail.store.exception.NotFoundException;
import com.retail.store.repository.DatabaseProgramDao;
import com.retail.store.repository.InventoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class InventoryService {

    private final InventoryRepository inventoryRepository;
    private final DatabaseProgramDao programDao;

    public List<Inventory> getAllInventory() {
        return inventoryRepository.findAllWithProduct();
    }

    public Inventory getInventory(String productId) {
        return inventoryRepository.findByProductProductId(productId)
                .orElseThrow(() -> new NotFoundException("库存记录不存在"));
    }

    /**
     * 库存调整（增量）：直接调用存储过程 usp_adjust_inventory，
     * 商品/操作员校验、库存不足判断、事务与审计记录全部由数据库完成。
     */
    public void adjustByProcedure(String productId, int adjustQty, String reason, int operatorId) {
        programDao.adjustInventory(productId, adjustQty, reason, operatorId);
        log.info("库存调整已提交存储过程: {} 增量={} 原因={} 操作员={}", productId, adjustQty, reason, operatorId);
    }

    public List<Inventory> getLowStock() {
        return inventoryRepository.findAllWithProduct().stream()
                .filter(i -> i.getQuantity() <= i.getMinThreshold())
                .toList();
    }

    /**
     * 补货建议：对每个商品调用函数 fn_restock_qty，
     * 仅返回需要补货（建议量 > 0）的商品。
     */
    public List<RestockSuggestion> getRestockSuggestions() {
        List<RestockSuggestion> result = new ArrayList<>();
        for (Inventory inv : inventoryRepository.findAllWithProduct()) {
            Integer qty = programDao.restockQty(inv.getProductId(), null);
            if (qty != null && qty > 0) {
                String name = inv.getProduct() != null ? inv.getProduct().getProductName() : "";
                result.add(new RestockSuggestion(
                        inv.getProductId(), name,
                        inv.getQuantity(), inv.getMinThreshold(), qty));
            }
        }
        return result;
    }
}
