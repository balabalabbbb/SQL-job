package com.retail.store.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class LoginRequest {
    @JsonProperty("login_type")
    private String loginType;  // employee / member
    private String account;    // 员工账号 或 会员手机号
    private String password;   // 员工密码（会员登录不需要）
    private String phone;      // 会员手机号
}
