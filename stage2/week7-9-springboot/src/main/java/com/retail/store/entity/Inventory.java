package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;
import com.fasterxml.jackson.annotation.JsonIgnore;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "inventory")
public class Inventory {
    @Id
    @Column(name = "inventory_id")
    private Integer inventoryId;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", insertable = false, updatable = false)
    private Product product;

    @Column(name = "product_id", length = 20)
    private String productId;

    @Column(name = "quantity")
    private Integer quantity;

    @Column(name = "shelf_location", length = 50)
    private String shelfLocation;

    @Column(name = "min_threshold")
    private Integer minThreshold;

    @Column(name = "last_updated")
    private LocalDateTime lastUpdated;

    @Transient
    private String productName;

    public String getProductName() {
        return product != null ? product.getProductName() : productName;
    }
}
