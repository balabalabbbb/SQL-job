# 小卖部管理系统 - Spring Boot Web应用

## 项目概述

基于 Spring Boot 3.2.5 + JDK 17 + SQL Server 构建的小卖部管理系统，采用四层架构：
**页面层(Controller) → 业务层(Service) → 数据访问层(Repository) → 数据库层(SQL Server)**

## 技术栈

| 层级 | 技术 |
|------|------|
| 页面层 | Spring MVC + Thymeleaf |
| 业务层 | Spring Service + @Transactional |
| 数据访问层 | Spring Data JPA + mssql-jdbc |
| 数据库 | SQL Server 2019 |
| 安全 | Spring Security + Session |
| 构建 | Maven 3.9+ |

## 目录结构

```
week7-9/
├── pom.xml
├── src/main/java/com/retail/store/
│   ├── RetailStoreApplication.java    # 主应用
│   ├── config/
│   │   └── SecurityConfig.java        # 安全配置
│   ├── controller/                    # 页面层
│   │   ├── AuthController.java
│   │   ├── ProductController.java
│   │   ├── InventoryController.java
│   │   └── OrderController.java
│   ├── service/                       # 业务层
│   │   ├── AuthService.java
│   │   ├── ProductService.java
│   │   ├── InventoryService.java
│   │   └── OrderService.java
│   ├── repository/                    # 数据访问层
│   │   ├── ProductRepository.java
│   │   ├── InventoryRepository.java
│   │   ├── OrderRepository.java
│   │   ├── OrderItemRepository.java
│   │   ├── MemberRepository.java
│   │   └── EmployeeRepository.java
│   ├── entity/                        # 实体类
│   ├── dto/                           # 数据传输对象
│   └── exception/                     # 异常体系
├── src/main/resources/
│   ├── application.properties
│   ├── templates/                     # Thymeleaf模板
│   └── static/style.css
└── src/test/java/                     # 集成测试
```

## 快速开始

### 1. 环境要求
- JDK 17+
- Maven 3.9+
- SQL Server 2019+（数据库 retail_store 已建库）

### 2. 配置数据库连接
编辑 `src/main/resources/application.properties`：
```properties
spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=retail_store;encrypt=true;trustServerCertificate=true
spring.datasource.username=retail_app
spring.datasource.password=retail123456
```

### 3. 编译运行
```bash
mvn clean package
java -jar target/retail-store-1.0.0.jar
```
或开发模式：
```bash
mvn spring-boot:run
```

### 4. 访问
浏览器打开 http://localhost:8080

## 测试账号

| 角色 | 账号 | 密码 | 权限 |
|------|------|------|------|
| 店长 | manager01 | Manager@123 | 全部操作 |
| 店员 | cashier01 | Manager@123 | 查询/库存/下单，不可管理商品 |
| 会员 | 13800138001 | （手机号登录） | 查询/下单 |

## 功能模块

### 1. 登录认证
- 员工登录（账号+密码，BCrypt验证）
- 会员登录（手机号）
- Session管理，未登录自动跳转登录页

### 2. 商品管理
- 商品列表查询（含类别名称）
- 新增商品（店长权限）
- 修改商品（店长权限）
- 删除商品（店长权限）
- 后端校验：ID非空、名称非空、价格非负、ID重复检查

### 3. 库存管理
- 库存列表查询（含商品名称）
- 低库存预警（数量≤阈值标红）
- 库存数量调整（店员/店长权限）
- 后端校验：数量非负

### 4. 订单管理
- 订单列表查询（含会员、收银员信息）
- 订单明细查询
- 创建订单（事务保证原子性）：
  1. 校验商品存在
  2. 校验库存充足
  3. 生成订单号（ORD+日期+4位序号）
  4. 写入订单主表
  5. 写入订单明细
  6. 扣减库存
  7. 更新会员积分
- 任意步骤失败 → 全部回滚

## 四层架构调用链路

### 查询示例：商品列表
```
浏览器 → AuthController.requireLogin()
       → ProductController.listProducts()
       → ProductService.getAllProducts()
       → ProductRepository.findAllWithCategory()
       → SQL Server (SELECT + JOIN category)
```

### 修改示例：创建订单
```
浏览器 → OrderController.createOrder()
       → AuthService.canCreateOrder()  [权限检查]
       → OrderService.createOrder()    [@Transactional]
         ├─ ProductRepository.findById()    [校验商品]
         ├─ InventoryRepository.findByProductProductId() [校验库存]
         ├─ OrderRepository.save()          [写订单]
         ├─ OrderItemRepository.save()      [写明细]
         ├─ InventoryRepository.deductStock() [扣库存]
         └─ MemberRepository.addPoints()    [加积分]
       → SQL Server
```

## 异常体系

| 异常类 | HTTP状态码 | 错误码 | 场景 |
|--------|-----------|--------|------|
| ValidationException | 400 | VALIDATION_ERROR | 参数校验失败 |
| AuthException | 401 | AUTH_ERROR | 未登录/认证失败 |
| PermissionDeniedException | 403 | PERMISSION_ERROR | 无权限 |
| NotFoundException | 404 | NOT_FOUND | 资源不存在 |
| BusinessRuleException | 409 | BUSINESS_RULE_ERROR | 业务规则冲突（库存不足） |
| ConstraintException | 400 | CONSTRAINT_ERROR | 数据库约束冲突 |
| DatabaseException | 500 | DATABASE_ERROR | 数据库操作失败 |
| TransactionException | 500 | TRANSACTION_ERROR | 事务失败 |

**统一响应格式**：
```json
{"success": true, "message": "操作成功", "data": {...}}
{"success": false, "message": "无权限执行此操作", "error_code": "PERMISSION_ERROR", "timestamp": "..."}
```

前端只显示 `message`，不暴露 SQL/堆栈/连接信息；详细错误写入 `logs/app.log`。

## 权限控制（三层一致）

1. **页面层**：Thymeleaf按角色显示/隐藏按钮
2. **业务层**：`AuthService.requireRole()` 强制校验，越权抛403
3. **数据库层**：`retail_app` 账户仅有 SELECT/INSERT/UPDATE/DELETE，无DDL权限

## 安全特性

- 所有SQL通过JPA参数化查询，无字符串拼接
- 密码BCrypt加密存储
- 统一异常处理，不泄露内部信息
- Session超时30分钟
- CSRF已禁用（API模式下使用自定义Session认证）
