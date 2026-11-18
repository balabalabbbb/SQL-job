-- ============================================================
-- recursive_query.sql
-- 第12周 层级递归查询（商品分类 — 子分类）
-- ============================================================
-- 层级结构（样例）：
--   1 全部商品（根）
--     ├─ 2 食品
--     │    ├─ 4 饮料
--     │    └─ 5 休闲零食
--     ├─ 3 日用品
--     └─ 6 文具
--          └─ 7 书写工具
-- 递归 CTE 三要素：起点（锚点）、递归连接（JOIN 子节点）、终止条件（无更多子节点）。
-- 输出：编号、名称、父级编号、层级、物化路径。
-- 路径列在锚点与递归部分保持一致的数据类型与长度（VARCHAR(400)）。
-- ============================================================

USE retail_store;
GO

SET NOCOUNT ON;
GO

-- ------------------------------------------------------------
-- 1. 准备样例数据（幂等：先清空再插入；外键自引用，先删子再删父）
-- ------------------------------------------------------------
DELETE FROM dbo.category_hierarchy;
INSERT INTO dbo.category_hierarchy (cat_id, cat_name, parent_id) VALUES
    (1, '全部商品', NULL),
    (2, '食品',     1),
    (3, '日用品',   1),
    (6, '文具',     1),
    (4, '饮料',     2),
    (5, '休闲零食', 2),
    (7, '书写工具', 6);
PRINT '已写入 7 个层级分类样例';
GO

-- ------------------------------------------------------------
-- 2. 递归查询：从指定起点查全部后代
-- ------------------------------------------------------------
-- 2.1 根节点（cat_id = 1），预期返回全部 7 个节点
PRINT '----- 递归查询1：根节点 cat_id=1（预期 7 行，含全部后代）-----';
DECLARE @start INT = 1;
WITH category_tree AS (
    -- 锚点：起点分类
    SELECT cat_id, cat_name, parent_id,
           1 AS category_level,
           CAST(cat_name AS VARCHAR(400)) AS hierarchy_path
    FROM dbo.category_hierarchy
    WHERE cat_id = @start
    UNION ALL
    -- 递归部分：连接直接子分类
    SELECT c.cat_id, c.cat_name, c.parent_id,
           ct.category_level + 1,
           CAST(ct.hierarchy_path + ' > ' + c.cat_name AS VARCHAR(400))
    FROM dbo.category_hierarchy c
    INNER JOIN category_tree ct ON c.parent_id = ct.cat_id
)
SELECT cat_id, cat_name, parent_id, category_level, hierarchy_path
FROM category_tree
ORDER BY category_level, cat_id
OPTION (MAXRECURSION 100);
GO

-- 2.2 中间节点（cat_id = 2 食品），预期返回 3 行（食品、饮料、休闲零食）
PRINT '----- 递归查询2：中间节点 cat_id=2（预期 3 行）-----';
DECLARE @start2 INT = 2;
WITH category_tree AS (
    SELECT cat_id, cat_name, parent_id,
           1 AS category_level,
           CAST(cat_name AS VARCHAR(400)) AS hierarchy_path
    FROM dbo.category_hierarchy
    WHERE cat_id = @start2
    UNION ALL
    SELECT c.cat_id, c.cat_name, c.parent_id,
           ct.category_level + 1,
           CAST(ct.hierarchy_path + ' > ' + c.cat_name AS VARCHAR(400))
    FROM dbo.category_hierarchy c
    INNER JOIN category_tree ct ON c.parent_id = ct.cat_id
)
SELECT cat_id, cat_name, parent_id, category_level, hierarchy_path
FROM category_tree
ORDER BY category_level, cat_id
OPTION (MAXRECURSION 100);
GO

-- 2.3 叶子节点（cat_id = 7 书写工具，无下级），预期只返回自身 1 行
PRINT '----- 递归查询3：叶子节点 cat_id=7（预期 1 行，仅自身）-----';
DECLARE @start3 INT = 7;
WITH category_tree AS (
    SELECT cat_id, cat_name, parent_id,
           1 AS category_level,
           CAST(cat_name AS VARCHAR(400)) AS hierarchy_path
    FROM dbo.category_hierarchy
    WHERE cat_id = @start3
    UNION ALL
    SELECT c.cat_id, c.cat_name, c.parent_id,
           ct.category_level + 1,
           CAST(ct.hierarchy_path + ' > ' + c.cat_name AS VARCHAR(400))
    FROM dbo.category_hierarchy c
    INNER JOIN category_tree ct ON c.parent_id = ct.cat_id
)
SELECT cat_id, cat_name, parent_id, category_level, hierarchy_path
FROM category_tree
ORDER BY category_level, cat_id
OPTION (MAXRECURSION 100);
GO

-- 2.4 不存在的编号（cat_id = 99），预期返回 0 行
PRINT '----- 递归查询4：不存在编号 cat_id=99（预期 0 行）-----';
DECLARE @start4 INT = 99;
WITH category_tree AS (
    SELECT cat_id, cat_name, parent_id,
           1 AS category_level,
           CAST(cat_name AS VARCHAR(400)) AS hierarchy_path
    FROM dbo.category_hierarchy
    WHERE cat_id = @start4
    UNION ALL
    SELECT c.cat_id, c.cat_name, c.parent_id,
           ct.category_level + 1,
           CAST(ct.hierarchy_path + ' > ' + c.cat_name AS VARCHAR(400))
    FROM dbo.category_hierarchy c
    INNER JOIN category_tree ct ON c.parent_id = ct.cat_id
)
SELECT cat_id, cat_name, parent_id, category_level, hierarchy_path
FROM category_tree
ORDER BY category_level, cat_id
OPTION (MAXRECURSION 100);
GO

PRINT 'recursive_query.sql 执行完成';
GO
