# 小卖部管理系统 - 数据库课程项目

中山大学数据库课程项目，以校园小卖部为真实经营场景，设计并实现完整的关系型数据库管理系统。项目已完成第一阶段（数据库原型）和第二阶段（规范化与Web应用）。

## 项目概览

| 项目 | 内容 |
|---|---|
| 场景 | 校园小卖部 |
| 核心对象 | 商品类别、商品、库存、订单、订单明细、会员、员工（7张表，v1.0） |
| 数据库 | SQL Server 2019+ |
| Web框架 | Spring Boot 3.2.5 + JDK 17 + Spring Data JPA + Thymeleaf |
| 小组 | 胡海博（组长）、胡懿桓、林一 |
| 仓库 | https://github.com/balabalabbbb/SQL-job |

## 阶段导航

| 阶段 | 周次 | 主题 | 状态 | 详细说明 |
|---|---|---|---|---|
| **第一阶段** | 第1-4周 | 可运行的数据库原型 v0.1 | ✅ 已完成 | [stage1/README.md](stage1/README.md) |
| **第二阶段** | 第5-6周 | ER图设计与规范化迁移 v1.0 | ✅ 已完成 | [stage2/week5](stage2/week5/)、[stage2/week6](stage2/week6/) |
| **第二阶段** | 第7-9周 | Spring Boot Web应用（四层架构） | ✅ 已完成 | [stage2/week7-9](stage2/week7-9/) |

## 第一阶段快速入口（v0.1）

- **SQL脚本**：[stage1/sql/](stage1/sql/) — 9个脚本按执行顺序编号
- **执行结果**：[stage1/result/](stage1/result/) — 本地实际执行输出 + 操作截图
- **阶段报告**：[stage1/第一阶段报告.md](stage1/第一阶段报告.md)
- **AI使用记录**：[stage1/AI使用记录.md](stage1/AI使用记录.md)
- **小组分工**：[stage1/小组分工报告.md](stage1/小组分工报告.md)

### v0.1 一键复现

```bash
# 使用 sqlcmd 执行（SQL Server 身份验证，替换为你的服务器和账号）
sqlcmd -S localhost -U sa -P your_password -i stage1/sql/01_create_database.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/02_create_tables.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/03_insert_sample_data.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/04_crud_operations.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/05_index_optimization.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/06_queries.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/07_views.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/08_constraints.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/sql/09_roles.sql
```

## 第二阶段快速入口

### 第5周：ER图与业务规则
- **ER图**：[stage2/week5/ER图.html](stage2/week5/ER图.html)（浏览器打开查看）
- **业务规则映射**：[stage2/week5/业务规则与映射清单.md](stage2/week5/业务规则与映射清单.md)
- **v0.1问题清单**：[stage2/week5/v0.1问题清单.md](stage2/week5/v0.1问题清单.md)

### 第6周：函数依赖与规范化迁移（v0.1 → v1.0）
- **依赖与范式分析**：[stage2/week6/依赖与范式分析.md](stage2/week6/依赖与范式分析.md)
- **数据字典（v1.0）**：[stage2/week6/数据字典.md](stage2/week6/数据字典.md)
- **迁移脚本**：[stage2/week6/migration.sql](stage2/week6/migration.sql)
- **回归测试**：[stage2/week6/regression.sql](stage2/week6/regression.sql)

### 第7-9周：Spring Boot Web应用
- **项目目录**：[stage2/week7-9/](stage2/week7-9/)
- **操作手册**：[stage2/week7-9/README.md](stage2/week7-9/README.md)
- **集成测试**：[stage2/week7-9/integration_test.ps1](stage2/week7-9/integration_test.ps1)（15项测试）
- **阶段报告**：[stage2/week7-9/阶段报告.md](stage2/week7-9/阶段报告.md)

#### 启动方式

```bash
cd stage2/week7-9
mvn package -DskipTests
java -jar target/retail-store-1.0.0.jar
# 访问 http://localhost:8080
```

#### 测试账号

| 角色 | 账号 | 密码 |
|---|---|---|
| 店长 | manager01 | Manager@123 |
| 店员 | cashier01 | Manager@123 |
| 会员 | 手机号 13800138001 | （手机号直接登录） |

## 目录结构

```
SQL-job/
├── README.md                    # 本文件（项目总览）
├── .gitignore
├── stage1/                      # 第一阶段：v0.1 数据库原型（第1-4周）
│   ├── README.md
│   ├── sql/                     # 统一SQL脚本（01-09）
│   ├── result/                  # 执行结果+截图
│   ├── 第一阶段报告.md
│   ├── AI使用记录.md
│   ├── 小组分工报告.md
│   └── week1/ ~ week4/          # 各周详细交付物
└── stage2/                      # 第二阶段：规范化与Web应用（第5-9周）
    ├── week5/                   # ER图设计与业务规则
    ├── week6/                   # 函数依赖分析与规范化迁移（v0.1→v1.0）
    └── week7-9/                 # Spring Boot Web应用（四层架构）
        ├── pom.xml
        ├── src/main/java/com/retail/store/
        │   ├── controller/      # 页面层（4个Controller）
        │   ├── service/         # 业务层（4个Service，含事务）
        │   ├── repository/      # 数据访问层（6个Repository）
        │   ├── entity/          # 实体类（7个）
        │   ├── exception/       # 异常体系（8类+全局处理器）
        │   ├── dto/             # 数据传输对象
        │   └── config/          # 安全配置
        ├── src/main/resources/
        │   ├── templates/       # Thymeleaf页面（6个）
        │   ├── static/          # CSS样式
        │   └── application.properties
        ├── integration_test.ps1 # 集成测试脚本
        ├── README.md            # 操作手册
        ├── 阶段报告.md
        ├── 小组分工报告.md
        └── AI使用记录.md
```

## 技术架构（第7-9周 Web应用）

```
页面层 (Controller + Thymeleaf)
    ↓ 调用
业务层 (Service + @Transactional)
    ↓ 调用
数据访问层 (Repository + JPA 参数化查询)
    ↓ 连接
数据库层 (SQL Server + 约束 + 视图 + 受限账户)
```

## 小组成员

| 姓名 | 学号 | 角色 | 贡献 |
|---|---|---|---|
| 胡海博 | 24325098 | 组长 | 50% |
| 胡懿桓 | 24325103 | 组员 | 25% |
| 林一 | 24325168 | 组员 | 25% |
