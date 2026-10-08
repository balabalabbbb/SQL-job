# 小卖部管理系统 - 数据库课程项目

中山大学数据库课程项目，以校园小卖部为真实经营场景，设计并实现完整的关系型数据库管理系统。项目周期17周，分四个阶段完成。

## 项目概览

| 项目 | 内容 |
|---|---|
| 场景 | 校园小卖部 |
| 核心对象 | 商品、库存、订单、订单明细、会员、员工（6张表，49字段） |
| 数据库 | SQL Server 2019+ |
| 小组 | 胡海博（组长）、胡懿桓、林一 |
| 仓库 | https://github.com/balabalabbbb/SQL-job |

## 阶段导航

| 阶段 | 周次 | 主题 | 状态 | 详细说明 |
|---|---|---|---|---|
| **第一阶段** | 第1-4周 | 可运行的数据库原型 v0.1 | ✅ 已完成 | [stage1/README.md](stage1/README.md) |
| **第二阶段** | 第5-8周 | 规范化与迁移 | 🔄 进行中（第5周完成） | [stage2/README.md](stage2/README.md) |
| **第三阶段** | 第9-12周 | （待规划） | ⏳ 未开始 | — |
| **第四阶段** | 第13-17周 | （待规划） | ⏳ 未开始 | — |

## 第一阶段快速入口

- **SQL脚本**：[stage1/sql/](stage1/sql/) — 9个脚本按执行顺序编号
- **执行结果**：[stage1/result/](stage1/result/) — 本地实际执行输出 + 操作截图（注：截图为MySQL环境下历史记录，脚本已迁移至SQL Server）
- **阶段报告**：[stage1/第一阶段报告.md](stage1/第一阶段报告.md)
- **AI使用记录**：[stage1/AI使用记录.md](stage1/AI使用记录.md)
- **小组分工**：[stage1/小组分工报告.md](stage1/小组分工报告.md)

### v0.1 一键复现

```bash
# 使用 sqlcmd 执行（SQL Server 身份验证，替换为你的服务器和账号）
sqlcmd -S localhost -U sa -P your_password -i stage1/week3/01_create_database.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week3/02_create_tables.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week3/03_insert_sample_data.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week3/05_index_optimization.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week4/query.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week4/view.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week4/constraint.sql
sqlcmd -S localhost -U sa -P your_password -d retail_store -i stage1/week4/role.sql
```

## 第二阶段快速入口

- **ER图**：[stage2/week5/ER图.html](stage2/week5/ER图.html)（浏览器打开查看）
- **业务规则映射**：[stage2/week5/业务规则与映射清单.md](stage2/week5/业务规则与映射清单.md)
- **v0.1问题清单**：[stage2/week5/v0.1问题清单.md](stage2/week5/v0.1问题清单.md)

## 目录结构

```
SQL-job/
├── README.md                    # 本文件（项目总览）
├── .gitignore
├── stage1/                      # 第一阶段：v0.1 数据库原型（第1-4周）
│   ├── README.md
│   ├── sql/                     # 统一SQL脚本
│   ├── result/                  # 执行结果+截图
│   ├── 第一阶段报告.md
│   ├── AI使用记录.md
│   ├── 小组分工报告.md
│   ├── week1/ ~ week4/          # 各周详细交付物
└── stage2/                      # 第二阶段：规范化与迁移（第5-8周）
    ├── README.md
    └── week5/                   # ER模型设计与验证
```

## 小组成员

| 姓名 | 学号 | 角色 |
|---|---|---|
| 胡海博 | 24325098 | 组长 |
| 胡懿桓 | 24325103 | 组员 |
| 林一 | 24325168 | 组员 |
