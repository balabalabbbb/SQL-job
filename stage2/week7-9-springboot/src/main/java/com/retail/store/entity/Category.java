package com.retail.store.entity;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "category")
public class Category {
    @Id
    @Column(name = "category_id")
    private Integer categoryId;

    @Column(name = "category_name", length = 50)
    private String categoryName;

    @Column(name = "description", length = 200)
    private String description;
}
