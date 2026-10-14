package com.retail.store.repository;

import com.retail.store.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, String> {
    @Query("SELECT p FROM Product p LEFT JOIN FETCH p.category ORDER BY p.productId")
    List<Product> findAllWithCategory();
}
