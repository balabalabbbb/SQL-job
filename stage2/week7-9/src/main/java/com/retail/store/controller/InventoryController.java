package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.dto.RestockSuggestion;
import com.retail.store.entity.Inventory;
import com.retail.store.exception.ValidationException;
import com.retail.store.service.AuthService;
import com.retail.store.service.InventoryService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Controller
@RequestMapping("/inventory")
@RequiredArgsConstructor
public class InventoryController {
    private final InventoryService inventoryService;
    private final AuthService authService;

    @GetMapping("/")
    public String inventoryPage(HttpSession session) {
        authService.requireLogin(session);
        return "inventory";
    }

    @GetMapping("/api/list")
    @ResponseBody
    public ApiResponse<List<Inventory>> listInventory(HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(inventoryService.getAllInventory());
    }

    @GetMapping("/api/low")
    @ResponseBody
    public ApiResponse<List<Inventory>> lowStock(HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(inventoryService.getLowStock());
    }

    /** 补货建议：调用 fn_restock_qty */
    @GetMapping("/api/restock")
    @ResponseBody
    public ApiResponse<List<RestockSuggestion>> restock(HttpSession session) {
        authService.canManageInventory(session);
        return ApiResponse.ok(inventoryService.getRestockSuggestions());
    }

    /**
     * 库存调整（增量 + 原因）：调用存储过程 usp_adjust_inventory。
     * 页面层只传参，校验/事务/审计由数据库完成。
     */
    @PostMapping("/api/adjust")
    @ResponseBody
    public ApiResponse<Void> adjust(@RequestBody Map<String, Object> data, HttpSession session) {
        authService.canManageInventory(session);

        String productId = (String) data.get("product_id");
        Object adjustObj = data.get("adjust_qty");
        String reason = data.get("reason") != null ? data.get("reason").toString() : null;
        if (productId == null || productId.isBlank()) {
            throw new ValidationException("商品编号不能为空");
        }
        if (adjustObj == null) {
            throw new ValidationException("调整数量不能为空");
        }
        int adjustQty;
        try {
            adjustQty = Integer.parseInt(adjustObj.toString());
        } catch (NumberFormatException e) {
            throw new ValidationException("调整数量必须是整数");
        }
        if (reason == null || reason.isBlank()) {
            throw new ValidationException("调整原因不能为空");
        }

        int operatorId = Integer.parseInt(session.getAttribute("userId").toString());
        inventoryService.adjustByProcedure(productId, adjustQty, reason, operatorId);
        return ApiResponse.ok("库存调整成功", null);
    }
}
