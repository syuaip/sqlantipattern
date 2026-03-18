# Consolidated Query Anti-Pattern Rules

A unified reference of query anti-patterns across five database platforms: **SQL Server**, **Oracle**, **MySQL**, **PostgreSQL**, and **MongoDB**.

**Sources**:
- `rules-sql-anti-pattern.md` — SQL Server (43 rules)
- `rules-oracle-anti-pattern.md` — Oracle (10 rules)
- `rules-mysql-anti-pattern.md` — MySQL (8 rules)
- `rules-postgres-anti-pattern.md` — PostgreSQL (13 rules)
- `rules-mongodb-anti-pattern.md` — MongoDB (6 rules)

---

## Table of Contents

- [A. Data Type Anti-Patterns](#a-data-type-anti-patterns)
- [B. Schema Design Anti-Patterns](#b-schema-design-anti-patterns)
- [C. Query Performance Anti-Patterns](#c-query-performance-anti-patterns)
- [D. Code Quality Anti-Patterns](#d-code-quality-anti-patterns)
- [E. Security Anti-Patterns](#e-security-anti-patterns)
- [F. Maintainability Anti-Patterns](#f-maintainability-anti-patterns)
- [G. Platform-Specific Anti-Patterns](#g-platform-specific-anti-patterns)
- [H. Diagnostic Tools by Platform](#h-diagnostic-tools-by-platform)
- [Quick Reference Summary](#quick-reference-summary)

---

## A. Data Type Anti-Patterns

### Rule A1: Avoid sql_variant Data Type
**Severity**: Medium | **Applies to**: SQL Server

Using `sql_variant` reduces type safety and query performance. It cannot be used in indexes, computed columns, or constraints, and requires explicit casting.

```sql
-- ❌ BAD
CREATE TABLE Products (
    ProductID INT,
    AttributeValue sql_variant
);

-- ✅ GOOD
CREATE TABLE Products (
    ProductID INT,
    AttributeValue NVARCHAR(500)
);
```

---

### Rule A2: Minimize Unicode Data Types (NCHAR/NVARCHAR)
**Severity**: Medium | **Applies to**: SQL Server

Unicode types consume 2x storage (2 bytes/char vs 1 byte). Use VARCHAR/CHAR for ASCII-only data; reserve NVARCHAR for international content.

```sql
-- ❌ BAD (if data is ASCII-only)
CREATE TABLE Customers (
    Email NVARCHAR(100),
    Phone NVARCHAR(20)
);

-- ✅ GOOD
CREATE TABLE Customers (
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Comments NVARCHAR(MAX)  -- Only for international content
);
```

---

### Rule A3: Avoid Single BIT Columns
**Severity**: Low | **Applies to**: SQL Server

A single BIT column consumes 1 full byte. SQL Server packs up to 8 BIT columns into 1 byte. For a single flag, consider TINYINT instead.

---

### Rule A4: Use VARCHAR(MAX) Only for Large Data
**Severity**: Medium | **Applies to**: SQL Server

VARCHAR(MAX) is stored off-row, cannot be indexed, and has slower sorting. Use VARCHAR(n) where n ≤ 8000 when possible.

---

### Rule A5: Use Fixed-Length Types for Small Data
**Severity**: Low | **Applies to**: SQL Server

For data consistently less than 4 characters (country codes, currency codes, status flags), use CHAR/NCHAR instead of VARCHAR/NVARCHAR to avoid the 2-byte length prefix overhead.

---

### Rule A6: Use Proper Data Types for XML
**Severity**: Medium | **Applies to**: SQL Server

Always use the XML data type for XML data, not VARCHAR/NVARCHAR. The XML type provides schema validation, XQuery support, XML indexes, and automatic compression.

---

### Rule A7: Use Appropriate Primary Key Data Types
**Severity**: Medium | **Applies to**: SQL Server, PostgreSQL

Choose PK data types based on requirements:

| Type | Use Case | Pros | Cons |
|------|----------|------|------|
| INT | Single database, < 2B rows | Small, fast, sequential | Limited range |
| BIGINT | Single database, > 2B rows | Large range, fast | 8 bytes |
| UUID/GUID | Distributed systems | Globally unique | Large, fragmentation |

**PostgreSQL-specific**: Avoid UUIDv4 (random, causes index fragmentation). Use **UUIDv7** (time-ordered) or `BIGINT` with `IDENTITY`.

**SQL Server-specific**: If GUID is needed, use `NEWSEQUENTIALID()` instead of `NEWID()` to reduce fragmentation.

---

### Rule A8: The "Text" Trap — CHAR(n) vs VARCHAR(n) vs TEXT
**Severity**: Medium | **Applies to**: PostgreSQL

In Postgres, there is no performance difference between `VARCHAR` and `TEXT`. Avoid `CHAR(n)` (pads with spaces) and arbitrary `VARCHAR(255)` limits. Use `TEXT` for variable-length strings.

---

### Rule A9: Store Timestamps with Time Zones
**Severity**: Medium | **Applies to**: PostgreSQL

Use `TIMESTAMPTZ` instead of `TIMESTAMP` to ensure the database handles UTC conversions and daylight savings correctly.

---

### Rule A10: Store IP Addresses as Binary
**Severity**: Medium | **Applies to**: MySQL

Storing `192.168.1.1` as `VARCHAR(15)` wastes space and slows searches. Use `INET6_ATON()` / `INET6_NTOA()` to store IPs as `VARBINARY(16)`.

---

## B. Schema Design Anti-Patterns

### Rule B1: Every Table Must Have a Primary Key
**Severity**: Critical | **Applies to**: All Platforms

Tables without a PK cannot uniquely identify rows, cannot establish foreign keys, allow duplicates, and have poor query performance.

---

### Rule B2: Prefer Single-Column Primary Keys
**Severity**: Medium | **Applies to**: All Platforms

Composite keys increase index size, complicate foreign key relationships, and slow joins. Use a surrogate key with a UNIQUE constraint on the natural key.

**Exceptions**: Junction/bridge tables, natural composite identifiers.

---

### Rule B3: Minimize Nullable Columns
**Severity**: Medium | **Applies to**: All Platforms

Default to NOT NULL. NULL introduces three-valued logic complexity, index inefficiency, and more complex query logic.

---

### Rule B4: Foreign Key Columns Must Be NOT NULL
**Severity**: High | **Applies to**: All Platforms

Nullable foreign keys break referential integrity and complicate join logic.

**Exception**: Optional relationships where NULL explicitly means "no relationship."

---

### Rule B5: Indexed Columns Should Be NOT NULL
**Severity**: Medium | **Applies to**: All Platforms (especially Oracle)

NULL values may not be indexed (database-dependent). In Oracle, standard B-tree indexes do not store entries where all indexed columns are null.

**Oracle Fix**: Use a Function-Based Index (e.g., `NVL(column, 'N/A')`) or provide a default value.

---

### Rule B6: Every Table Must Have Indexes
**Severity**: Critical | **Applies to**: All Platforms

Tables without indexes cause full table/collection scans. Add indexes on foreign keys, WHERE clause columns, JOIN conditions, and ORDER BY columns.

---

### Rule B7: Index Columns Used in WHERE Clauses
**Severity**: High | **Applies to**: All Platforms

Columns frequently used in WHERE clauses must have supporting indexes. Design compound indexes with the most selective column first.

---

### Rule B8: Avoid Triggers When Possible
**Severity**: High | **Applies to**: SQL Server, Oracle

Triggers create hidden logic that's difficult to debug, trace, and test. Use explicit stored procedures instead.

**When acceptable**: Audit logging, complex business rules that cannot be done with constraints.

---

### Rule B9: Avoid SQL Reserved Words for Names
**Severity**: Medium | **Applies to**: All Platforms

Reserved words as table/column names require delimiters everywhere, cause syntax errors, and reduce portability.

---

### Rule B10: Remove Unused Tables
**Severity**: Low | **Applies to**: All Platforms

Tables defined in DDL but never used waste storage, increase backup/restore overhead, and create a confusing schema.

---

### Rule B11: Over-reliance on JSONB for Relational Data
**Severity**: Medium | **Applies to**: PostgreSQL

Storing everything in a single JSONB blob loses strict typing, constraints, and the query planner's ability to use statistics. Use standard columns for stable data; use JSONB only for truly dynamic or unstructured data.

---

## C. Query Performance Anti-Patterns

### Rule C1: Avoid Functions on Columns in Predicates
**Severity**: Critical | **Applies to**: All Platforms

Never apply functions to columns in WHERE, JOIN, or ON clauses. This prevents index usage and forces full table/collection scans (10–100x slower).

**SQL Server**:
```sql
-- ❌ BAD
WHERE YEAR(OrderDate) = 2024
WHERE UPPER(LastName) = 'SMITH'

-- ✅ GOOD
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'
WHERE LastName = 'Smith'  -- Use case-insensitive collation
```

**Oracle**:
```sql
-- ❌ BAD
WHERE TRUNC(created_date) = TO_DATE('2026-01-01', 'YYYY-MM-DD')

-- ✅ GOOD
WHERE created_date >= TO_DATE('2026-01-01', 'YYYY-MM-DD')
  AND created_date < TO_DATE('2026-01-02', 'YYYY-MM-DD')
```

**PostgreSQL**:
```sql
-- ❌ BAD
WHERE date_trunc('day', created_at) = '2026-03-12'

-- ✅ GOOD
WHERE created_at >= '2026-03-12' AND created_at < '2026-03-13'
```

**MySQL**:
```sql
-- ❌ BAD
WHERE age + 1 > 18

-- ✅ GOOD
WHERE age > 17
```

---

### Rule C2: Avoid SELECT * (Wildcard Selection / Blind Projections)
**Severity**: High | **Applies to**: All Platforms

Always specify explicit column names. SELECT * retrieves unnecessary data, breaks on schema changes, prevents covering indexes, and wastes network/memory.

**MongoDB equivalent**: Always project only the necessary fields.
```javascript
// ❌ BAD
db.users.find({ email: "user@example.com" })

// ✅ GOOD
db.users.find({ email: "user@example.com" }, { username: 1, _id: 0 })
```

---

### Rule C3: Always Use Explicit JOIN Syntax
**Severity**: High | **Applies to**: SQL Server, Oracle, MySQL, PostgreSQL

Use explicit JOIN syntax (INNER JOIN, LEFT JOIN) instead of implicit joins (comma-separated tables in FROM with conditions in WHERE).

**Oracle-specific**: Replace the old `(+)` outer join syntax with ANSI `LEFT JOIN`.

```sql
-- ❌ BAD (implicit join)
SELECT o.OrderID, c.CustomerName
FROM Orders o, Customers c
WHERE o.CustomerID = c.CustomerID;

-- ✅ GOOD (explicit join)
SELECT o.OrderID, c.CustomerName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID;
```

---

### Rule C4: Avoid Negative Conditions in WHERE ($ne, <>, NOT IN)
**Severity**: Medium | **Applies to**: All Platforms

Negative conditions prevent efficient index usage and force table/collection scans.

**SQL/Relational**:
```sql
-- ❌ BAD
WHERE Status <> 'Cancelled'

-- ✅ GOOD
WHERE Status IN ('Pending', 'Shipped', 'Delivered')
```

**MongoDB**:
```javascript
// ❌ BAD
db.products.find({ status: { $ne: "discontinued" } })

// ✅ GOOD
db.products.find({ status: { $in: ["active", "out_of_stock", "preorder"] } })
```

---

### Rule C5: Avoid Leading Wildcards in LIKE / Regex
**Severity**: High | **Applies to**: All Platforms

`LIKE '%keyword%'` or regex with leading wildcards forces full table/collection scans.

| Platform | Fix |
|----------|-----|
| SQL Server | Use FULLTEXT index |
| Oracle | Use Oracle Text (`CONTAINS`) |
| MySQL | Use FULLTEXT index or Elasticsearch |
| PostgreSQL | Use GIN index with `pg_trgm` extension |
| MongoDB | Store normalized field + standard index, or use Collation |

**MongoDB-specific (Case-Insensitive Regex Trap)**:
```javascript
// ❌ BAD — /i flag prevents index usage
db.users.find({ username: /^johndoe$/i })

// ✅ GOOD — Store normalized lowercase version
db.users.find({ username_low: "johndoe" })
```

---

### Rule C6: Always Include WHERE Clause in SELECT
**Severity**: Medium | **Applies to**: All Platforms

SELECT without WHERE returns the entire table. Use WHERE, TOP/LIMIT, or pagination.

**Exceptions**: Small lookup tables (< 100 rows), aggregate queries.

---

### Rule C7: Always Include WHERE in UPDATE/DELETE
**Severity**: Critical | **Applies to**: All Platforms

UPDATE/DELETE without WHERE affects ALL rows — catastrophic data loss risk.

```sql
-- ❌ DANGEROUS
DELETE FROM Orders;

-- ✅ GOOD
DELETE FROM Orders WHERE Status = 'Cancelled' AND CreatedDate < DATEADD(YEAR, -7, GETDATE());
```

---

### Rule C8: Implement Pagination for Large Result Sets
**Severity**: High | **Applies to**: All Platforms

Queries returning large result sets without pagination cause memory exhaustion and poor UX.

**Avoid high-offset pagination** (all platforms):
```sql
-- ❌ BAD — scans and discards thousands of rows
OFFSET 100000 ROWS FETCH NEXT 10 ROWS ONLY  -- Oracle/SQL Server
LIMIT 10 OFFSET 100000                       -- PostgreSQL/MySQL
```

**Use Keyset (Cursor-based) Pagination**:
```sql
-- ✅ GOOD
WHERE id > :last_seen_id ORDER BY id FETCH FIRST 10 ROWS ONLY  -- Oracle
WHERE id > @last_seen_id ORDER BY id OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY  -- SQL Server
WHERE id > last_id ORDER BY id LIMIT 10  -- PostgreSQL/MySQL
```

---

### Rule C9: UNION vs. UNION ALL
**Severity**: High | **Applies to**: SQL Server, Oracle, MySQL, PostgreSQL

`UNION` performs an implicit DISTINCT sort to remove duplicates, which is memory-intensive. Use `UNION ALL` unless you specifically need deduplication.

```sql
-- ❌ BAD (unnecessary sort)
SELECT ... FROM current_data UNION SELECT ... FROM archive_data

-- ✅ GOOD (if rows are inherently distinct)
SELECT ... FROM current_data UNION ALL SELECT ... FROM archive_data
```

---

### Rule C10: Avoid CURSOR / Row-by-Row Processing
**Severity**: Critical | **Applies to**: SQL Server, Oracle

Cursors and row-by-row loops (RBAR — Row By Agonizing Row) are 100–1000x slower than set-based operations.

**SQL Server**:
```sql
-- ❌ BAD (CURSOR)
DECLARE cur CURSOR FOR SELECT CustomerID FROM Customers;
-- ... WHILE @@FETCH_STATUS = 0 ...

-- ✅ GOOD (set-based)
UPDATE c SET TotalOrders = o.Total
FROM Customers c
INNER JOIN (SELECT CustomerID, SUM(Amount) AS Total FROM Orders GROUP BY CustomerID) o
ON c.CustomerID = o.CustomerID;
```

**Oracle (PL/SQL)**:
```sql
-- ❌ BAD (FOR loop, one-at-a-time)
FOR rec IN (SELECT * FROM source_table) LOOP
    INSERT INTO target_table VALUES (rec.col1, rec.col2);
END LOOP;

-- ✅ GOOD (Bulk Collect + FORALL)
FETCH cursor BULK COLLECT INTO l_data LIMIT 1000;
FORALL i IN 1..l_data.COUNT
    INSERT INTO target_table VALUES l_data(i);
```

---

### Rule C11: Avoid SELECT in WHILE Loops
**Severity**: Critical | **Applies to**: SQL Server

Never use SELECT statements inside WHILE loops. Use set-based operations instead.

---

### Rule C12: Avoid Scalar UDFs in SELECT Lists
**Severity**: High | **Applies to**: SQL Server

Scalar User-Defined Functions in SELECT execute once per row (RBAR). Replace with inline JOINs or inline table-valued functions.

---

### Rule C13: Always Use ORDER BY with TOP/LIMIT
**Severity**: High | **Applies to**: All Platforms

TOP/LIMIT without ORDER BY returns non-deterministic results.

---

### Rule C14: Avoid ORDER BY in SELECT INTO
**Severity**: Low | **Applies to**: SQL Server

ORDER BY in SELECT INTO is ignored. Sort when you actually need the results.

---

### Rule C15: The DISTINCT Crutch
**Severity**: Medium | **Applies to**: Oracle, PostgreSQL

Adding DISTINCT to "fix" a JOIN that produces duplicate rows is a symptom, not a solution. Fix the join logic or use `EXISTS`.

---

### Rule C16: OR Conditions on Different Columns
**Severity**: High | **Applies to**: MySQL, PostgreSQL

`WHERE col_a = x OR col_b = y` often forces a full table scan even if both columns are indexed.

**Fix**: Use `UNION` / `UNION ALL` to combine two separate indexed queries.

---

### Rule C17: NOT IN with Subqueries (NULL Trap)
**Severity**: High | **Applies to**: PostgreSQL, SQL Server

If the subquery returns a single NULL, the entire `NOT IN` result becomes empty. Use `NOT EXISTS` or `LEFT JOIN ... WHERE ... IS NULL` instead.

---

### Rule C18: ORDER BY RAND()
**Severity**: High | **Applies to**: MySQL

`ORDER BY RAND()` generates a random number for every row, sorts them all, then picks one. For 1M rows, that's 1M random numbers + a full sort.

**Fix**: Generate a random ID in application code and query that specific ID.

---

### Rule C19: Avoid Query Hints Unless Necessary
**Severity**: Medium | **Applies to**: SQL Server, Oracle

Query hints (NOLOCK, FORCESEEK, etc.) override the optimizer and can cause worse performance. Use only after thorough testing.

---

### Rule C20: Implicit Type Conversion
**Severity**: High | **Applies to**: Oracle

Comparing a VARCHAR2 column to a numeric literal (e.g., `WHERE string_id = 123`) causes Oracle to internally wrap the column in `TO_NUMBER()`, disabling the index.

**Fix**: Always match the data type: `WHERE string_id = '123'`.

---

### Rule C21: Using Literals Instead of Bind Variables
**Severity**: High | **Applies to**: Oracle

Hardcoded literals prevent execution plan reuse in the Library Cache, causing expensive "Hard Parses."

**Fix**: Use bind variables (`:id`) so Oracle can reuse execution plans.

---

### Rule C22: The IN (SELECT ...) Performance Hole
**Severity**: Medium | **Applies to**: MySQL

In older MySQL versions (pre-5.7/8.0), `WHERE id IN (SELECT id FROM ...)` was re-executed for every row. Use a `JOIN` or `EXISTS` instead.

---

### Rule C23: Joining on Mismatched Collations
**Severity**: High | **Applies to**: MySQL

Joining tables with different collations (e.g., `utf8mb4_general_ci` vs `utf8mb4_unicode_ci`) prevents index usage. Ensure all related columns share the same character set and collation.

---

### Rule C24: SELECT COUNT(*) on Large InnoDB Tables
**Severity**: Medium | **Applies to**: MySQL

InnoDB does not store an internal row count. `COUNT(*)` without WHERE requires a full index scan. Use `SHOW TABLE STATUS` or maintain a separate counter table if exact count isn't needed.

---

### Rule C25: Searching for NULL in Standard Indexes
**Severity**: Medium | **Applies to**: Oracle

In Oracle, standard B-tree indexes do not store entries where all indexed columns are null. `WHERE status IS NULL` cannot use the index.

**Fix**: Use a Function-Based Index (e.g., `NVL(column, 'N/A')`) or provide a default value.

---

## D. Code Quality Anti-Patterns

### Rule D1: Always Specify Columns in INSERT
**Severity**: Medium | **Applies to**: All Platforms

INSERT without explicit column names breaks when columns are added or reordered.

```sql
-- ❌ BAD
INSERT INTO Customers VALUES ('John', 'Doe', 'john@example.com');

-- ✅ GOOD
INSERT INTO Customers (FirstName, LastName, Email)
VALUES ('John', 'Doe', 'john@example.com');
```

---

### Rule D2: Remove Unused Parameters and Variables
**Severity**: Low | **Applies to**: SQL Server, Oracle

Unused input parameters and local variables create confusing interfaces and maintenance overhead.

---

### Rule D3: Avoid SELECT for Variable Assignment
**Severity**: Low | **Applies to**: SQL Server

Use SET for single variable assignment. SELECT can assign from multiple rows (last value wins), leading to unpredictable behavior.

---

### Rule D4: Avoid sp_ Prefix for Stored Procedures
**Severity**: Medium | **Applies to**: SQL Server

SQL Server checks the master database first for `sp_` prefixed procedures, causing performance overhead. Use `usp_` or schema-qualified names.

---

### Rule D5: Avoid fn_ Prefix for Functions
**Severity**: Low | **Applies to**: SQL Server

Similar to sp_ issue. Use descriptive names or `ufn_` prefix.

---

### Rule D6: Use Meaningful Names
**Severity**: Low | **Applies to**: All Platforms

Use descriptive, meaningful names for all database objects. Avoid single-letter table names, cryptic abbreviations, and inconsistent naming.

---

### Rule D7: Document Complex Logic
**Severity**: Low | **Applies to**: All Platforms

Add comments to explain complex business logic, not obvious code. Include business rules, calculation explanations, and last-updated metadata.

---

## E. Security Anti-Patterns

### Rule E1: Avoid Dynamic SQL with String Concatenation
**Severity**: Critical | **Applies to**: All Platforms

Never build dynamic SQL using string concatenation with user input — this is the #1 SQL injection vector.

```sql
-- ❌ DANGEROUS
SET @SQL = 'SELECT * FROM Customers WHERE Name = ''' + @Input + '''';
EXEC(@SQL);

-- ✅ GOOD (parameterized)
SELECT * FROM Customers WHERE Name = @Input;

-- ✅ ACCEPTABLE (sp_executesql with parameters)
EXEC sp_executesql @SQL, N'@Name VARCHAR(100)', @Name = @Input;
```

---

### Rule E2: Avoid Hardcoded Credentials
**Severity**: Critical | **Applies to**: All Platforms

Never hardcode passwords, connection strings, or secrets in SQL code. Use linked servers, Windows Authentication, or secret management tools.

---

## F. Maintainability Anti-Patterns

### Rule F1: Avoid ORDER BY in Views
**Severity**: Medium | **Applies to**: SQL Server

ORDER BY in views is ignored (unless with TOP/OFFSET). Sort when querying the view.

---

## G. Platform-Specific Anti-Patterns

### MongoDB-Specific

#### Rule G1: Large Arrays and $unwind
**Severity**: High | **Applies to**: MongoDB

Using `$unwind` on very large arrays early in an aggregation pipeline explodes the number of documents in memory (100MB RAM limit per stage).

```javascript
// ❌ BAD — Unwinding everything just to filter
db.orders.aggregate([
  { $unwind: "$items" },
  { $match: { "items.status": "shipped" } }
])

// ✅ GOOD — Filter first, then use $filter
db.orders.aggregate([
  { $match: { "items.status": "shipped" } },
  { $project: {
      shipped_items: {
        $filter: {
          input: "$items",
          as: "item",
          cond: { $eq: ["$item.status", "shipped"] }
        }
      }
  }}
])
```

---

#### Rule G2: Unbounded $lookup (The "Join" Abuse)
**Severity**: High | **Applies to**: MongoDB

Using `$lookup` to join two massive collections without initial filtering mimics relational behavior but is significantly slower in a document store.

```javascript
// ❌ BAD — No filtering before $lookup
db.orders.aggregate([
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" } }
])

// ✅ GOOD — $match before $lookup
db.orders.aggregate([
  { $match: { orderDate: { $gte: ISODate("2026-03-01") } } },
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" } }
])
```

---

#### Rule G3: Massive "In-Memory" Sorting
**Severity**: High | **Applies to**: MongoDB

Sorting on a field that isn't indexed fails if the sort exceeds 32MB RAM (or is very slow with `allowDiskUse`).

```javascript
// ❌ BAD — 'score' is not indexed
db.players.find().sort({ score: -1 })

// ✅ GOOD — Create compound index: { teamId: 1, score: -1 } (ESR Rule)
db.players.find({ teamId: "red_dragons" }).sort({ score: -1 })
```

---

### Oracle-Specific

#### Rule G4: Traditional Oracle Joins ((+) Syntax)
**Severity**: Medium | **Applies to**: Oracle

The old `WHERE a.id = b.id(+)` syntax is harder to read and more error-prone. Use ANSI `LEFT JOIN` syntax.

---

### PostgreSQL-Specific

#### Rule G5: The N+1 Query Pattern
**Severity**: High | **Applies to**: PostgreSQL (common in ORMs)

Fetching a list of records and then running a separate query for each record to get related data.

**Fix**: Use a single `JOIN` or `CTE` to fetch all data in one trip.

---

#### Rule G6: Correlated Subqueries in SELECT
**Severity**: High | **Applies to**: PostgreSQL, SQL Server

Running a subquery for every row in the result set.

```sql
-- ❌ BAD
SELECT name, (SELECT count(*) FROM orders WHERE user_id = u.id) FROM users u

-- ✅ GOOD
SELECT u.name, COALESCE(o.cnt, 0)
FROM users u
LEFT JOIN (SELECT user_id, count(*) AS cnt FROM orders GROUP BY user_id) o
ON u.id = o.user_id
```

---

## H. Diagnostic Tools by Platform

| Platform | Command | What to Look For |
|----------|---------|------------------|
| **SQL Server** | `SET STATISTICS IO ON; SET STATISTICS TIME ON;` | Logical reads, CPU time |
| **Oracle** | `EXPLAIN PLAN FOR [query]; SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);` | "TABLE ACCESS FULL" on large tables |
| **MySQL** | `EXPLAIN ANALYZE [query]` (MySQL 8.0+) | Rows examined, actual time |
| **PostgreSQL** | `EXPLAIN (ANALYZE, BUFFERS) [query]` | Seq Scan vs Index Scan |
| **MongoDB** | `.explain("executionStats")` | COLLSCAN (bad) vs IXSCAN (good) |

---

## Quick Reference Summary

| Rule | Severity | Platforms | Category |
|------|----------|-----------|----------|
| A1. Avoid sql_variant | Medium | SQL Server | Data Type |
| A2. Minimize NVARCHAR | Medium | SQL Server | Data Type |
| A3. Avoid Single BIT | Low | SQL Server | Data Type |
| A4. VARCHAR(MAX) for Large Data | Medium | SQL Server | Data Type |
| A5. CHAR for Small Data | Low | SQL Server | Data Type |
| A6. Use XML Type | Medium | SQL Server | Data Type |
| A7. Appropriate PK Type | Medium | SQL Server, PostgreSQL | Data Type |
| A8. TEXT vs VARCHAR in Postgres | Medium | PostgreSQL | Data Type |
| A9. TIMESTAMPTZ | Medium | PostgreSQL | Data Type |
| A10. IP as Binary | Medium | MySQL | Data Type |
| B1. Every Table Needs PK | Critical | All | Schema |
| B2. Single-Column PK | Medium | All | Schema |
| B3. Minimize NULL | Medium | All | Schema |
| B4. FK Must Be NOT NULL | High | All | Schema |
| B5. Indexed Columns NOT NULL | Medium | All (esp. Oracle) | Schema |
| B6. Tables Need Indexes | Critical | All | Schema |
| B7. Index WHERE Columns | High | All | Schema |
| B8. Avoid Triggers | High | SQL Server, Oracle | Schema |
| B9. Avoid Reserved Words | Medium | All | Schema |
| B10. Remove Unused Tables | Low | All | Schema |
| B11. JSONB Overuse | Medium | PostgreSQL | Schema |
| C1. No Functions on Columns | Critical | All | Performance |
| C2. Avoid SELECT * | High | All | Performance |
| C3. Explicit JOIN Syntax | High | All Relational | Performance |
| C4. Avoid Negative Conditions | Medium | All | Performance |
| C5. No Leading Wildcards | High | All | Performance |
| C6. Include WHERE in SELECT | Medium | All | Performance |
| C7. WHERE in UPDATE/DELETE | Critical | All | Data Safety |
| C8. Implement Pagination | High | All | Performance |
| C9. UNION ALL over UNION | High | All Relational | Performance |
| C10. Avoid CURSOR/RBAR | Critical | SQL Server, Oracle | Performance |
| C11. No SELECT in WHILE | Critical | SQL Server | Performance |
| C12. Avoid Scalar UDF | High | SQL Server | Performance |
| C13. ORDER BY with TOP | High | All | Performance |
| C14. No ORDER BY in SELECT INTO | Low | SQL Server | Performance |
| C15. DISTINCT Crutch | Medium | Oracle, PostgreSQL | Performance |
| C16. OR on Different Columns | High | MySQL, PostgreSQL | Performance |
| C17. NOT IN NULL Trap | High | PostgreSQL, SQL Server | Performance |
| C18. ORDER BY RAND() | High | MySQL | Performance |
| C19. Avoid Query Hints | Medium | SQL Server, Oracle | Performance |
| C20. Implicit Type Conversion | High | Oracle | Performance |
| C21. Literals vs Bind Variables | High | Oracle | Performance |
| C22. IN (SELECT ...) Hole | Medium | MySQL | Performance |
| C23. Mismatched Collations | High | MySQL | Performance |
| C24. COUNT(*) on InnoDB | Medium | MySQL | Performance |
| C25. NULL in Oracle Indexes | Medium | Oracle | Performance |
| D1. Specify INSERT Columns | Medium | All | Code Quality |
| D2. Remove Unused Params | Low | SQL Server, Oracle | Code Quality |
| D3. SET for Variables | Low | SQL Server | Code Quality |
| D4. Avoid sp_ Prefix | Medium | SQL Server | Code Quality |
| D5. Avoid fn_ Prefix | Low | SQL Server | Code Quality |
| D6. Meaningful Names | Low | All | Code Quality |
| D7. Document Complex Logic | Low | All | Maintainability |
| E1. No Dynamic SQL Concat | Critical | All | Security |
| E2. No Hardcoded Credentials | Critical | All | Security |
| F1. No ORDER BY in Views | Medium | SQL Server | Maintainability |
| G1. $unwind on Large Arrays | High | MongoDB | Performance |
| G2. Unbounded $lookup | High | MongoDB | Performance |
| G3. In-Memory Sorting | High | MongoDB | Performance |
| G4. Oracle (+) Syntax | Medium | Oracle | Code Quality |
| G5. N+1 Query Pattern | High | PostgreSQL | Performance |
| G6. Correlated Subqueries | High | PostgreSQL, SQL Server | Performance |

---

**Document Version**: 1.0
**Last Updated**: 2026-03-18
**Sources**: rules-sql-anti-pattern.md, rules-oracle-anti-pattern.md, rules-mysql-anti-pattern.md, rules-postgres-anti-pattern.md, rules-mongodb-anti-pattern.md
