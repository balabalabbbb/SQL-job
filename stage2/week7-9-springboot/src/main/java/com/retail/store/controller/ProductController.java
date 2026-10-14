package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.entity.Product;
import com.retail.store.service.AuthService;
import com.retail.store.service.ProductService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
@RequestMapping("/products")
@RequiredArgsConstructor
public class ProductController {
    private final ProductService productService;
    private final AuthService authService;

    @GetMapping("/")
    public String productsPage(HttpSession session) {
        authService.requireLogin(session);
        return "products";
    }

    @GetMapping("/api/list")
    @ResponseBody
    public ApiResponse<List<Product>> listProducts(HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(productService.getAllProducts());
    }

    @GetMapping("/api/{productId}")
    @ResponseBody
    public ApiResponse<Product> getProduct(@PathVariable String productId, HttpSession session) {
        authService.requireLogin(session);
        return ApiResponse.ok(productService.getProduct(productId));
    }

    @PostMapping("/api/add")
    @ResponseBody
    public ApiResponse<Product> addProduct(@RequestBody Product product, HttpSession session) {
        authService.canManageProducts(session);
        return ApiResponse.ok("商品创建成功", productService.createProduct(product));
    }

    @PostMapping("/api/update")
    @ResponseBody
    public ApiResponse<Product> updateProduct(@RequestBody Product product, HttpSession session) {
        authService.canManageProducts(session);
        return ApiResponse.ok("商品更新成功", productService.updateProduct(product.getProductId(), product));
    }

    @PostMapping("/api/delete/{productId}")
    @ResponseBody
    public ApiResponse<String> deleteProduct(@PathVariable String productId, HttpSession session) {
        authService.canManageProducts(session);
        productService.deleteProduct(productId);
        return ApiResponse.ok("商品删除成功", null);
    }
}
