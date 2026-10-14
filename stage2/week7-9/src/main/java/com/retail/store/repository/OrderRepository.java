package com.retail.store.repository;

import com.retail.store.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface OrderRepository extends JpaRepository<Order, String> {
    @Query("SELECT o FROM Order o LEFT JOIN FETCH o.member LEFT JOIN FETCH o.cashier ORDER BY o.orderTime DESC")
    List<Order> findAllWithRelations();

    @Query("SELECT MAX(CAST(SUBSTRING(o.orderId, 12, 4) AS int)) FROM Order o WHERE o.orderId LIKE :prefix")
    Integer findMaxSeqByPrefix(String prefix);
}
