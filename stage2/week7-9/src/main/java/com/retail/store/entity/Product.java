package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import com.fasterxml.jackson.annotation.JsonIgnore;
import java.math.BigDecimal;

@Data
@Entity
@Table(name = "product")
public class Product {
    @Id
    @Column(name = "product_id", length = 20)
    private String productId;

    @Column(name = "product_name", length = 100, nullable = false)
    private String productName;

    @Column(name = "sale_price", precision = 10, scale = 2)
    private BigDecimal salePrice;

    @Column(name = "purchase_price", precision = 10, scale = 2)
    private BigDecimal purchasePrice;

    @Column(name = "unit", length = 20)
    private String unit;

    @Column(name = "supplier", length = 100)
    private String supplier;

    @Column(name = "status", length = 20)
    private String status;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", insertable = false, updatable = false)
    private Category category;

    @Column(name = "category_id", length = 20)
    private String categoryId;

    @Transient
    private String categoryName;

    public String getCategoryName() {
        return category != null ? category.getCategoryName() : categoryName;
    }
}
