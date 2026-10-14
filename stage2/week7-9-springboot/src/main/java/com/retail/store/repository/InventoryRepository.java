package com.retail.store.repository;

import com.retail.store.entity.Inventory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface InventoryRepository extends JpaRepository<Inventory, Integer> {
    @Query("SELECT i FROM Inventory i LEFT JOIN FETCH i.product ORDER BY i.productId")
    List<Inventory> findAllWithProduct();

    Optional<Inventory> findByProductProductId(String productId);

    @Modifying
    @Query("UPDATE Inventory i SET i.quantity = i.quantity - :qty, i.lastUpdated = CURRENT_TIMESTAMP WHERE i.productId = :productId AND i.quantity >= :qty")
    int deductStock(@Param("productId") String productId, @Param("qty") int qty);
}
