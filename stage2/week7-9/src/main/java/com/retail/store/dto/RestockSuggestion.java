package com.retail.store.dto;

/** 补货建议行：当前库存、最低阈值与函数计算出的建议补货量 */
public record RestockSuggestion(
        String productId,
        String productName,
        int currentQty,
        int minThreshold,
        int restockQty) {
}
