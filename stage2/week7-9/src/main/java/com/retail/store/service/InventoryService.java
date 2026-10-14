package com.retail.store.service;

import com.retail.store.entity.Inventory;
import com.retail.store.exception.NotFoundException;
import com.retail.store.exception.ValidationException;
import com.retail.store.repository.InventoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class InventoryService {
    private final InventoryRepository inventoryRepository;

    public List<Inventory> getAllInventory() {
        return inventoryRepository.findAllWithProduct();
    }

    public Inventory getInventory(String productId) {
        return inventoryRepository.findByProductProductId(productId)
                .orElseThrow(() -> new NotFoundException("库存记录不存在"));
    }

    @Transactional
    public Inventory adjustInventory(String productId, int quantity, int minThreshold) {
        Inventory inv = getInventory(productId);
        if (quantity < 0) {
            throw new ValidationException("库存数量不能为负数");
        }
        inv.setQuantity(quantity);
        inv.setMinThreshold(minThreshold);
        inv.setLastUpdated(LocalDateTime.now());
        log.info("调整库存: {} 数量={} 阈值={}", productId, quantity, minThreshold);
        return inventoryRepository.save(inv);
    }

    public List<Inventory> getLowStock() {
        return inventoryRepository.findAllWithProduct().stream()
                .filter(i -> i.getQuantity() <= i.getMinThreshold())
                .toList();
    }
}
