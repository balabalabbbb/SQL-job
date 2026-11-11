package com.retail.store.dto;

import java.math.BigDecimal;
import java.util.List;

/** 销售统计存储过程结果：整体汇总（输出参数）+ 商品明细（结果集） */
public record SalesStatistics(
        int orderCount,
        int salesQty,
        BigDecimal salesAmount,
        List<SalesSummaryRow> details) {
}
