package com.retail.store.dto;

import java.math.BigDecimal;

/** 销售汇总/统计中的单个商品行（对应 fn_sales_summary 与 usp_sales_statistics 明细） */
public record SalesSummaryRow(
        String productId,
        String productName,
        int salesQty,
        BigDecimal salesAmount,
        int orderCount) {
}
