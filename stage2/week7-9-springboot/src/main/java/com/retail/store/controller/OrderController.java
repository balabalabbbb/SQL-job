package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.dto.OrderRequest;
import com.retail.store.entity.Order;
import com.retail.store.service.AuthService;
import com.retail.store.service.OrderService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Controller
@RequestMapping("/orders")
@RequiredArgsConstructor
public class OrderController {
    private final OrderService orderService;
    private final AuthService authService;

    @GetMapping("/")
    public String ordersPage(HttpSession session) {
        authService.requireLogin(session);
        return "orders";
    }

    @GetMapping("/create")
    public String createPage(HttpSession session) {
        authService.requireLogin(session);
        return "order_create";
    }

    @GetMapping("/api/list")
    @ResponseBody
    public ApiResponse<List<Order>> listOrders(HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(orderService.getAllOrders());
    }

    @GetMapping("/api/{orderId}")
    @ResponseBody
    public ApiResponse<Map<String, Object>> getOrder(@PathVariable String orderId, HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(orderService.getOrderDetail(orderId));
    }

    @PostMapping("/api/create")
    @ResponseBody
    public ApiResponse<Map<String, Object>> createOrder(@RequestBody OrderRequest request, HttpSession session) {
        authService.canCreateOrder(session);
        String cashierId = null;
        if ("employee".equals(session.getAttribute("userType"))) {
            cashierId = (String) session.getAttribute("userId");
        }
        if (request.getMemberId() == null) {
            request.setMemberId("M0001");
        }
        return ApiResponse.ok("订单创建成功", orderService.createOrder(request, cashierId));
    }

    @PostMapping("/api/cancel/{orderId}")
    @ResponseBody
    public ApiResponse<Map<String, Object>> cancelOrder(@PathVariable String orderId, HttpSession session) {
        authService.canCreateOrder(session);
        return ApiResponse.ok("订单取消成功", orderService.cancelOrder(orderId));
    }
}
