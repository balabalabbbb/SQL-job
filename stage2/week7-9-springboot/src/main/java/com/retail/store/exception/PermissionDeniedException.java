package com.retail.store.exception;

public class PermissionDeniedException extends AppException {
    public PermissionDeniedException(String message) {
        super("PERMISSION_ERROR", 403, message, message);
    }
}
