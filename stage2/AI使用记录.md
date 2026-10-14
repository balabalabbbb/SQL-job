# AI 使用记录 - 小卖部管理系统 Web 应用开发

## 项目信息
- **项目名称**：小卖部管理系统（Spring Boot 版）
- **阶段**：第二阶段（第7-9周）Web 应用开发
- **AI 工具**：豆包办公（Doubao Work）
- **记录日期**：2026-10-14

## AI 辅助过程记录

### 1. 项目架构设计

**AI 建议**：
- 推荐使用 Spring Boot 3.2.5 + JDK 17 + Spring Data JPA + Thymeleaf 技术栈
- 建议四层架构：Controller（页面层）→ Service（业务层）→ Repository（数据访问层）→ SQL Server（数据库层）
- 建议使用 Spring Security 进行权限控制，Session 管理用户会话

**人工决策**：
- 采纳 AI 建议的技术栈和架构
- 选择 JPA 而非 MyBatis，因为 JPA 自动参数化查询更安全
- 选择 Thymeleaf 而非前后端分离，因为课程要求 Web 界面程序，服务端渲染更简单

**验证结论**：架构设计合理，15 项集成测试全部通过，各层职责清晰。

---

### 2. 实体类与 JPA 映射

**AI 建议**：
- 7 个实体类：Category、Product、Inventory、Member、Employee、Order、OrderItem
- 使用 @ManyToOne 映射外键关联
- 使用 @JsonIgnore 防止循环引用和懒加载序列化问题

**遇到的问题**：
- Hibernate 懒加载代理对象 Jackson 无法序列化，报 `could not initialize proxy`

**AI 解决方案**：
- 在所有 @ManyToOne 字段添加 @JsonIgnore
- 添加外键列的直接映射字段（categoryId、memberId、cashierId、productId、orderId）
- 关联字段设置 insertable=false, updatable=false

**人工修改**：
- 采纳 AI 方案，修改全部 7 个实体类
- 验证保存和查询功能正常

**验证结论**：实体映射正确，JSON 序列化无错误，CRUD 操作正常。

---

### 3. BCrypt 密码验证

**AI 建议**：
- 使用 Spring Security 的 BCryptPasswordEncoder 进行密码加密和验证
- 数据库存储 BCrypt hash，不存储明文密码

**遇到的问题**：
- 使用 Python bcrypt 生成的 hash 前缀为 `$2b$`，Spring Security 不支持，报 `Invalid salt version`

**AI 解决方案**：
- 生成 `$2a$` 前缀的 BCrypt hash（Spring Security 兼容版本）
- 用新 hash 更新数据库中员工的 login_password 字段

**人工修改**：
- 手动执行 SQL 更新员工密码 hash
- 验证登录功能正常

**验证结论**：员工登录成功，BCrypt 验证正常。

---

### 4. 订单创建事务

**AI 建议**：
- 使用 @Transactional(rollbackFor = Exception.class) 确保事务原子性
- 7 步流程：校验商品→校验库存→生成订单号→写订单主表→写订单明细→扣减库存→更新积分
- 任意步骤失败抛出异常，触发回滚

**遇到的问题**：
- InventoryRepository.deductStock 方法缺少 @Modifying 注解，Hibernate 报 `Expecting a SELECT query`

**AI 解决方案**：
- 在 deductStock 方法添加 @Modifying 注解
- JPQL 中使用直接映射字段 productId 而非关联对象 product.productId

**人工修改**：
- 修改 InventoryRepository，添加 @Modifying
- 重新打包测试

**验证结论**：订单创建成功，事务回滚正常（测试非法外码时全部回滚）。

---

### 5. 中文编码问题

**AI 建议**：
- 在 application.properties 中添加 UTF-8 编码配置
- JDBC URL 添加 sendStringParametersAsUnicode=true

**遇到的问题**：
- 订单 payment_method 字段的 CHECK 约束冲突，中文"现金"无法匹配约束中的值

**AI 解决方案**：
- 添加 server.servlet.encoding.force=true
- JDBC URL 添加 characterEncoding=UTF-8
- 请求头使用 Content-Type: application/json; charset=utf-8

**人工修改**：
- 修改 application.properties
- 测试脚本中添加 charset=utf-8

**验证结论**：中文正常存储和查询，CHECK 约束正常工作。

---

### 6. 统一异常处理

**AI 建议**：
- 设计 8 类自定义异常：Validation、Auth、PermissionDenied、NotFound、BusinessRule、Constraint、Database、Transaction
- 使用 @RestControllerAdvice 全局异常处理器
- 统一响应格式：{success, message, error_code, timestamp}
- 前端只显示友好 message，不暴露内部细节

**人工决策**：
- 采纳 AI 建议的异常体系
- 详细错误写入日志文件 logs/app.log

**验证结论**：各类异常正确返回对应 HTTP 状态码和错误码，前端不暴露 SQL/堆栈信息。

---

### 7. 前端登录页面问题

**AI 建议**：
- 使用 Tab 切换员工/会员登录
- fetch API 提交 JSON 数据

**遇到的问题**：
- 员工登录在浏览器中点击无反应，API 测试正常
- 控制台报错 `An invalid form control with name='' is not focusable`

**AI 诊断**：
- 隐藏的会员手机号 input 有 required 属性但没有 name 属性
- 浏览器表单验证时尝试聚焦隐藏字段，失败后阻止提交

**AI 解决方案**：
- 给所有 input 添加 name 属性
- 移除隐藏字段的静态 required
- 在 switchTab 函数中动态设置 required

**人工修改**：
- 修改 login.html
- 浏览器测试员工登录成功

**验证结论**：员工和会员登录均正常。

---

### 8. 页面美化

**AI 建议**：
- 渐变配色方案（紫蓝渐变主色）
- 卡片式布局，hover 动画
- 表格斑马纹和行高亮
- 按钮渐变和阴影
- 侧边栏深色主题

**人工决策**：
- 采纳 AI 美化方案
- 保持功能不变，仅优化视觉

**验证结论**：页面美观，功能正常，响应式适配。

---

### 9. 集成测试

**AI 建议**：
- 编写 PowerShell 集成测试脚本
- 覆盖 15 项测试：登录、CRUD、事务、约束、权限、异常
- 自动统计通过/失败数，导出 CSV 结果

**人工修改**：
- 运行测试脚本，验证全部通过
- 根据测试结果修复发现的问题

**验证结论**：15/15 全部通过。

---

## AI 建议与人工修改汇总表

| 序号 | AI 建议 | 人工修改 | 验证结论 |
|------|---------|----------|----------|
| 1 | 四层架构 + Spring Boot 技术栈 | 采纳 | 架构合理 |
| 2 | @JsonIgnore + 外键直接映射 | 采纳 | 序列化正常 |
| 3 | $2a$ 前缀 BCrypt hash | 采纳 | 登录正常 |
| 4 | @Modifying 注解 | 采纳 | 扣库存正常 |
| 5 | UTF-8 强制编码 | 采纳 | 中文正常 |
| 6 | 8 类异常 + 全局处理器 | 采纳 | 异常处理规范 |
| 7 | 动态 required + name 属性 | 采纳 | 登录正常 |
| 8 | 渐变配色美化 | 采纳 | 页面美观 |
| 9 | PowerShell 集成测试 | 采纳 | 15/15 通过 |

## 人工验证工作

1. **环境配置验证**：手动配置 JDK、Maven、SQL Server TCP/IP
2. **数据库验证**：使用 sqlcmd 验证表结构、约束、数据
3. **功能测试**：浏览器实际操作各功能模块
4. **权限测试**：分别用店长/店员/会员账号测试越权操作
5. **事务测试**：验证非法外码时订单和库存不被修改
6. **代码审查**：组长审查全部代码，确保规范和安全

## 总结

AI 在本项目中主要承担了**代码生成、问题诊断、方案设计**的角色，显著提高了开发效率。关键问题（懒加载序列化、BCrypt 兼容性、@Modifying、表单验证）均由 AI 快速定位并给出解决方案。

人工工作主要集中在**环境配置、决策判断、测试验证**上，确保 AI 生成的代码符合业务需求和安全规范。所有 AI 建议均经过人工验证后才采纳，没有盲目信任 AI 输出。

**AI 贡献率约 60%**（代码生成和问题诊断），**人工贡献率约 40%**（环境配置、决策、测试、文档）。
