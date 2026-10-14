package com.retail.store.dto;

import lombok.Data;
import java.util.List;

@Data
public class OrderRequest {
    private List<OrderItemRequest> items;
    private String paymentMethod;
    private String memberId;
    private String remark;

    @Data
    public static class OrderItemRequest {
        private String productId;
        private int quantity;
    }
}
