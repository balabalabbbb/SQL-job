package com.retail.store.exception;

public class ConstraintException extends AppException {
    public ConstraintException(String message) {
        super("CONSTRAINT_ERROR", 400, "数据约束冲突，请检查输入", message);
    }
}
