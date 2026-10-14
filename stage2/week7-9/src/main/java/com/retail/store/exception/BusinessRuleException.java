package com.retail.store.exception;

public class BusinessRuleException extends AppException {
    public BusinessRuleException(String message) {
        super("BUSINESS_RULE_ERROR", 409, message, message);
    }
}
