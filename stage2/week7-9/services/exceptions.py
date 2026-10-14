class AppError(Exception):
    error_code = 'APP_ERROR'
    http_status = 400
    user_message = '操作失败'

    def __init__(self, detail=""):
        self.detail = detail
        super().__init__(self.user_message)


class ValidationError(AppError):
    error_code = 'VALIDATION_ERROR'
    http_status = 400
    user_message = '参数校验失败'


class AuthError(AppError):
    error_code = 'AUTH_ERROR'
    http_status = 401
    user_message = '未登录或登录已过期'


class PermissionDeniedError(AppError):
    error_code = 'PERMISSION_ERROR'
    http_status = 403
    user_message = '无权限执行此操作'


class NotFoundError(AppError):
    error_code = 'NOT_FOUND'
    http_status = 404
    user_message = '资源不存在'


class BusinessRuleError(AppError):
    error_code = 'BUSINESS_RULE_ERROR'
    http_status = 409
    user_message = '业务规则冲突'


class ConstraintConflictError(AppError):
    error_code = 'CONSTRAINT_CONFLICT'
    http_status = 409
    user_message = '数据约束冲突'


class DBConnectionError(AppError):
    error_code = 'DB_CONNECTION_ERROR'
    http_status = 500
    user_message = '数据库连接失败'


class TransactionError(AppError):
    error_code = 'TRANSACTION_ERROR'
    http_status = 500
    user_message = '事务执行失败，已回滚'
