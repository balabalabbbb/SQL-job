package com.retail.store.exception;

import lombok.Getter;

@Getter
public class AppException extends RuntimeException {
    private final String errorCode;
    private final int httpStatus;
    private final String detail;

    public AppException(String errorCode, int httpStatus, String message, String detail) {
        super(message);
        this.errorCode = errorCode;
        this.httpStatus = httpStatus;
        this.detail = detail;
    }
}
