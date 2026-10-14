package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "inventory")
public class Inventory {
    @Id
    @Column(name = "inventory_id")
    private Integer inventoryId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id")
    private Product product;

    @Column(name = "quantity")
    private Integer quantity;

    @Column(name = "shelf_location", length = 50)
    private String shelfLocation;

    @Column(name = "min_threshold")
    private Integer minThreshold;

    @Column(name = "last_updated")
    private LocalDateTime lastUpdated;

    @Transient
    private String productId;

    @Transient
    private String productName;

    public String getProductId() {
        return product != null ? product.getProductId() : productId;
    }

    public String getProductName() {
        return product != null ? product.getProductName() : productName;
    }
}
