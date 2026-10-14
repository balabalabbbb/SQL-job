package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "employee")
public class Employee {
    @Id
    @Column(name = "employee_id", length = 20)
    private String employeeId;

    @Column(name = "employee_name", length = 50)
    private String employeeName;

    @Column(name = "position", length = 20)
    private String position;

    @Column(name = "login_account", length = 50)
    private String loginAccount;

    @Column(name = "login_password", length = 100)
    private String loginPassword;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "hire_date")
    private LocalDate hireDate;

    @Column(name = "employee_status", length = 20)
    private String employeeStatus;

    @Column(name = "last_login_time")
    private LocalDateTime lastLoginTime;

    @Transient
    private String role;

    public String getRole() {
        if ("店长".equals(position)) return "manager";
        if ("店员".equals(position)) return "cashier";
        return "cashier";
    }
}
