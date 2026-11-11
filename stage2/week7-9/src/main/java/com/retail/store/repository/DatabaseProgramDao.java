package com.retail.store.repository;

import com.retail.store.dto.SalesSummaryRow;
import com.retail.store.dto.SalesStatistics;
import com.retail.store.exception.BusinessRuleException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * 数据库程序对象统一访问层：
 * 集中调用第10周在 SQL Server 中创建的存储过程与函数，
 * 业务规则（库存调整、折扣、补货、销售统计/汇总）全部在数据库内实现，
 * 页面/业务层只负责传参与展示，不在 Java 中重写规则。
 */
@Slf4j
@Repository
@RequiredArgsConstructor
public class DatabaseProgramDao {

    private final JdbcTemplate jdbcTemplate;

    // ----------------------------------------------------------------
    // 一、标量函数调用
    // ----------------------------------------------------------------

    /** 补货量函数：target 为 null 时使用 DEFAULT（目标=最低阈值×2）；商品不存在返回 null */
    public Integer restockQty(String productId, Integer targetQty) {
        if (targetQty == null) {
            return jdbcTemplate.queryForObject(
                    "SELECT dbo.fn_restock_qty(?, DEFAULT)", Integer.class, productId);
        }
        return jdbcTemplate.queryForObject(
                "SELECT dbo.fn_restock_qty(?, ?)", Integer.class, productId, targetQty);
    }

    /** 折扣率函数：会员编号（可空）+ 折前金额 → 折扣率；会员不存在返回 null */
    public BigDecimal discountRate(String memberId, BigDecimal originalAmount) {
        return jdbcTemplate.queryForObject(
                "SELECT dbo.fn_discount_rate(?, ?)", BigDecimal.class, memberId, originalAmount);
    }

    /** 折扣金额函数：折前金额 + 折扣率 → 折扣金额；非法入参返回 null */
    public BigDecimal discountAmount(BigDecimal originalAmount, BigDecimal rate) {
        return jdbcTemplate.queryForObject(
                "SELECT dbo.fn_discount_amount(?, ?)", BigDecimal.class, originalAmount, rate);
    }

    // ----------------------------------------------------------------
    // 二、表值函数调用
    // ----------------------------------------------------------------

    /** 销售汇总表值函数：返回日期范围内全部商品的汇总（无销售为 0） */
    public List<SalesSummaryRow> salesSummary(LocalDate start, LocalDate end) {
        return jdbcTemplate.query(
                "SELECT product_id, product_name, sales_qty, sales_amount, order_count " +
                "FROM dbo.fn_sales_summary(?, ?)",
                (rs, n) -> new SalesSummaryRow(
                        rs.getString("product_id"),
                        rs.getString("product_name"),
                        rs.getInt("sales_qty"),
                        rs.getBigDecimal("sales_amount"),
                        rs.getInt("order_count")),
                start, end);
    }

    // ----------------------------------------------------------------
    // 三、存储过程调用
    // ----------------------------------------------------------------

    /** 库存调整存储过程：事务内更新库存并写调整记录；规则不满足时数据库抛错 */
    public void adjustInventory(String productId, int adjustQty, String reason, int operatorId) {
        SimpleJdbcCall call = new SimpleJdbcCall(jdbcTemplate)
                .withProcedureName("usp_adjust_inventory");
        MapSqlParameterSource in = new MapSqlParameterSource()
                .addValue("product_id", productId)
                .addValue("adjust_qty", adjustQty)
                .addValue("reason", reason)
                .addValue("operator_id", operatorId);
        try {
            call.execute(in);
        } catch (DataAccessException ex) {
            throw translateError(ex);
        }
    }

    /** 销售统计存储过程：输出参数返回整体汇总，结果集返回商品明细 */
    @SuppressWarnings("unchecked")
    public SalesStatistics salesStatistics(LocalDate start, LocalDate end) {
        SimpleJdbcCall call = new SimpleJdbcCall(jdbcTemplate)
                .withProcedureName("usp_sales_statistics")
                .declareParameters(
                        new SqlParameter("start_date", Types.DATE),
                        new SqlParameter("end_date", Types.DATE),
                        new SqlOutParameter("order_count", Types.INTEGER),
                        new SqlOutParameter("sales_qty", Types.INTEGER),
                        new SqlOutParameter("sales_amount", Types.DECIMAL))
                .returningResultSet("product_rows",
                        (rs, n) -> new SalesSummaryRow(
                                rs.getString("product_id"),
                                rs.getString("product_name"),
                                rs.getInt("sales_qty"),
                                rs.getBigDecimal("sales_amount"),
                                rs.getInt("order_count")));

        MapSqlParameterSource in = new MapSqlParameterSource()
                .addValue("start_date", start)
                .addValue("end_date", end);
        Map<String, Object> out;
        try {
            out = call.execute(in);
        } catch (DataAccessException ex) {
            throw translateError(ex);
        }

        Integer orderCount = (Integer) out.get("order_count");
        Integer salesQty = (Integer) out.get("sales_qty");
        BigDecimal salesAmount = (BigDecimal) out.get("sales_amount");
        List<SalesSummaryRow> rows = (List<SalesSummaryRow>) out.get("product_rows");
        return new SalesStatistics(
                orderCount != null ? orderCount : 0,
                salesQty != null ? salesQty : 0,
                salesAmount != null ? salesAmount : BigDecimal.ZERO,
                rows);
    }

    /**
     * 把存储过程抛出的数据库异常转换为业务异常：
     * 错误号 50000+ 是后端预置的业务校验（如商品不存在、库存不足、日期非法），
     * 其消息为中文业务提示、不含 SQL/堆栈，转成 BusinessRuleException（HTTP 409）返回前端；
     * 其余异常（连接失败、语法等）原样抛出，由统一异常处理层兜底为系统错误。
     */
    private RuntimeException translateError(DataAccessException ex) {
        Throwable cause = ex;
        while (cause != null && !(cause instanceof SQLException)) {
            cause = cause.getCause();
        }
        if (cause instanceof SQLException sqlException) {
            int errorCode = sqlException.getErrorCode();
            if (errorCode >= 50000) {
                log.warn("存储过程业务校验失败 errorCode={} message={}", errorCode, sqlException.getMessage());
                return new BusinessRuleException(sqlException.getMessage());
            }
        }
        return ex;
    }
}
