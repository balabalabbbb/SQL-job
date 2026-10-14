package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.entity.Inventory;
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

    @PostMapping("/api/update")
    @ResponseBody
    public ApiResponse<Inventory> updateInventory(@RequestBody Map<String, Object> data, HttpSession session) {
        authService.canManageInventory(session);
        String productId = (String) data.get("product_id");
        int quantity = Integer.parseInt(data.get("quantity").toString());
        int minThreshold = Integer.parseInt(data.get("min_threshold").toString());
        return ApiResponse.ok("库存更新成功", inventoryService.adjustInventory(productId, quantity, minThreshold));
    }
}
