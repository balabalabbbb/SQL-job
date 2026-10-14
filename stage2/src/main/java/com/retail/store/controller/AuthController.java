package com.retail.store.controller;

import com.retail.store.dto.ApiResponse;
import com.retail.store.dto.LoginRequest;
import com.retail.store.service.AuthService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@Controller
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @GetMapping("/login")
    public String loginPage() {
        return "login";
    }

    @PostMapping("/login")
    @ResponseBody
    public ApiResponse<Map<String, Object>> login(@RequestBody LoginRequest request, HttpSession session) {
        Map<String, Object> result = authService.login(request, session);
        return ApiResponse.ok("登录成功", result);
    }

    @PostMapping("/logout")
    @ResponseBody
    public ApiResponse<String> logout(HttpSession session) {
        session.invalidate();
        return ApiResponse.ok("登出成功", null);
    }

    @GetMapping("/")
    public String index(HttpSession session) {
        if (session.getAttribute("userId") == null) {
            return "redirect:/login";
        }
        return "index";
    }
}
