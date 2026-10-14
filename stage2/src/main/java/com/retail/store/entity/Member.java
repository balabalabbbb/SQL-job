package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "member")
public class Member {
    @Id
    @Column(name = "member_id", length = 20)
    private String memberId;

    @Column(name = "member_name", length = 50)
    private String memberName;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "register_time")
    private LocalDateTime registerTime;

    @Column(name = "points_balance")
    private Integer pointsBalance;

    @Column(name = "member_level", length = 20)
    private String memberLevel;

    @Column(name = "total_spent", precision = 10, scale = 2)
    private java.math.BigDecimal totalSpent;

    @Column(name = "member_status", length = 20)
    private String memberStatus;
}
