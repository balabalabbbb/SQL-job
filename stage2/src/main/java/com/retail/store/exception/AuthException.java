package com.retail.store.exception;

public class AuthException extends AppException {
    public AuthException(String message) {
        super("AUTH_ERROR", 401, message, message);
    }
}
