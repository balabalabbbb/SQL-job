package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import com.fasterxml.jackson.annotation.JsonIgnore;
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

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", insertable = false, updatable = false)
    private Member member;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cashier_id", insertable = false, updatable = false)
    private Employee cashier;

    @Column(name = "member_id", length = 20)
    private String memberId;

    @Column(name = "cashier_id", length = 20)
    private String cashierId;

    @Column(name = "remark", length = 200)
    private String remark;

    @JsonIgnore
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
