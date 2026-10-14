package com.retail.store.exception;

public class DatabaseException extends AppException {
    public DatabaseException(String message) {
        super("DATABASE_ERROR", 500, "数据库操作失败，请稍后重试", message);
    }
}
