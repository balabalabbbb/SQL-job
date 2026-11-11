package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.dto.SalesStatistics;
import com.retail.store.dto.SalesSummaryRow;
import com.retail.store.service.AuthService;
import com.retail.store.service.SalesService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@Controller
@RequestMapping("/sales")
@RequiredArgsConstructor
public class SalesController {

    private final SalesService salesService;
    private final AuthService authService;

    @GetMapping("/")
    public String salesPage(HttpSession session) {
        authService.canManageInventory(session);
        return "sales";
    }

    /** 销售统计：调用存储过程 */
    @GetMapping("/api/statistics")
    @ResponseBody
    public ApiResponse<SalesStatistics> statistics(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate end,
            HttpSession session) {
        authService.canManageInventory(session);
        return ApiResponse.ok(salesService.getStatistics(start, end));
    }

    /** 销售汇总：调用表值函数 */
    @GetMapping("/api/summary")
    @ResponseBody
    public ApiResponse<List<SalesSummaryRow>> summary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate end,
            HttpSession session) {
        authService.canManageInventory(session);
        return ApiResponse.ok(salesService.getSummary(start, end));
    }
}
