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

    /**
     * 新格式订单号（ORD+4位序号，长度7，如 ORD0014）的最大序号。
     * 用于生成下一订单号，避免用 count+1 在删除订单后产生重复主键。
     */
    @Query("SELECT MAX(CAST(SUBSTRING(o.orderId, 4, 4) AS int)) FROM Order o " +
           "WHERE LENGTH(o.orderId) = 7 AND o.orderId LIKE 'ORD%'")
    Integer findMaxShortSeq();
}
