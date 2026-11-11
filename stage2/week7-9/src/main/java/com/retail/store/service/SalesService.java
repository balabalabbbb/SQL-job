package com.retail.store.service;

import com.retail.store.dto.SalesStatistics;
import com.retail.store.dto.SalesSummaryRow;
import com.retail.store.repository.DatabaseProgramDao;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

/** 销售分析业务层：只负责传参，统计逻辑由数据库存储过程/函数实现 */
@Service
@RequiredArgsConstructor
public class SalesService {

    private final DatabaseProgramDao programDao;

    /** 销售统计（存储过程：输出参数 + 明细结果集） */
    public SalesStatistics getStatistics(LocalDate start, LocalDate end) {
        return programDao.salesStatistics(start, end);
    }

    /** 销售汇总（表值函数，可在 SELECT 中调用） */
    public List<SalesSummaryRow> getSummary(LocalDate start, LocalDate end) {
        return programDao.salesSummary(start, end);
    }
}
