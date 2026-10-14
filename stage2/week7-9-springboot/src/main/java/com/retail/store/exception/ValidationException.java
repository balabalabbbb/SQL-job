package com.retail.store.exception;

public class ValidationException extends AppException {
    public ValidationException(String message) {
        super("VALIDATION_ERROR", 400, message, message);
    }
}
