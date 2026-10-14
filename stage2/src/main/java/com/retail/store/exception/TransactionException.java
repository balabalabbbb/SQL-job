package com.retail.store.exception;

public class TransactionException extends AppException {
    public TransactionException(String message) {
        super("TRANSACTION_ERROR", 500, "事务执行失败，已回滚", message);
    }
}
