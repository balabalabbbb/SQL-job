package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@Entity
@Table(name = "orders")
public class Order {
    @Id
    @Column(name = "order_id", length = 20)
    private String orderId;

    @Column(name = "order_time")
    private LocalDateTime orderTime;

    @Column(name = "total_amount", precision = 10, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "payment_method", length = 20)
    private String paymentMethod;

    @Column(name = "order_status", length = 20)
    private String orderStatus;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cashier_id")
    private Employee cashier;

    @Column(name = "remark", length = 200)
    private String remark;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<OrderItem> items = new ArrayList<>();

    @Transient
    private String memberName;

    @Transient
    private String employeeName;

    public String getMemberName() {
        return member != null ? member.getMemberName() : memberName;
    }

    public String getEmployeeName() {
        return cashier != null ? cashier.getEmployeeName() : employeeName;
    }
}
