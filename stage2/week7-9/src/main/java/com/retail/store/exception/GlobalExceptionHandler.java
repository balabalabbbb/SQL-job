package com.retail.store.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.ModelAndView;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(AppException.class)
    public Object handleAppException(AppException e, WebRequest request) {
        log.error("错误码={} HTTP={} 详情={}", e.getErrorCode(), e.getHttpStatus(), e.getDetail());

        // 浏览器访问返回HTML页面，API调用返回JSON
        String accept = request.getHeader("Accept");
        if (accept != null && accept.contains("text/html")) {
            ModelAndView mav = new ModelAndView("error");
            mav.addObject("errorCode", e.getErrorCode());
            mav.addObject("message", e.getMessage());
            mav.addObject("title", getTitleByErrorCode(e.getErrorCode()));
            mav.setStatus(e.getHttpStatus());
            return mav;
        }

        Map<String, Object> body = new HashMap<>();
        body.put("success", false);
        body.put("message", e.getMessage());
        body.put("error_code", e.getErrorCode());
        body.put("timestamp", LocalDateTime.now().toString());
        return ResponseEntity.status(e.getHttpStatus()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public Object handleException(Exception e, WebRequest request) {
        log.error("未预期异常: {}", e.getMessage(), e);

        String accept = request.getHeader("Accept");
        if (accept != null && accept.contains("text/html")) {
            ModelAndView mav = new ModelAndView("error");
            mav.addObject("errorCode", "SYSTEM_ERROR");
            mav.addObject("message", "系统暂时无法完成操作，请稍后重试");
            mav.addObject("title", "系统异常");
            mav.setStatus(HttpStatus.INTERNAL_SERVER_ERROR);
            return mav;
        }

        Map<String, Object> body = new HashMap<>();
        body.put("success", false);
        body.put("message", "系统暂时无法完成操作，请稍后重试");
        body.put("error_code", "SYSTEM_ERROR");
        body.put("timestamp", LocalDateTime.now().toString());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }

    private String getTitleByErrorCode(String errorCode) {
        switch (errorCode) {
            case "AUTH_ERROR":
                return "请先登录";
            case "PERMISSION_DENIED":
                return "权限不足";
            case "VALIDATION_ERROR":
                return "输入有误";
            case "NOT_FOUND":
                return "资源不存在";
            case "BUSINESS_ERROR":
                return "操作无法完成";
            default:
                return "操作提示";
        }
    }
}
