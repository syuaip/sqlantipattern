# Additional Query Anti-Pattern Rules (Proposed Extension)

Proposed additions to `rules-consolidated-query-anti-pattern.md`. Numbering continues the
existing scheme (A/B/C/D/E categories extended; two new categories **I** and **J** added).
Each rule follows the consolidated file's format and includes a **Remediation Effort**
(S = < 0.5 day, M = 0.5–2 days, L = > 2 days) so the Kiro remediation-plan prompt can
estimate man-days reliably.

Platforms: **SQL Server**, **Oracle**, **MySQL**, **PostgreSQL**, **MongoDB**.

---

## A. Data Type Anti-Patterns (continued)

### Rule A11: Never Use FLOAT/REAL for Money
**Severity**: High | **Effort**: M | **Applies to**: All Platforms

Binary floating-point types cannot represent decimal fractions exactly, causing rounding
drift in financial sums. Use fixed-point `DECIMAL`/`NUMERIC`.

```sql
-- ❌ BAD
Price FLOAT, Balance REAL
-- ✅ GOOD
Price DECIMAL(12,2), Balance NUMERIC(18,4)
```
MongoDB: use `Decimal128`, not `double`, for currency.

---

### Rule A12: Do Not Store Dates or Numbers as Strings
**Severity**: High | **Effort**: M | **Applies to**: All Platforms

Storing `'2026-03-01'` or `'12345'` in a `VARCHAR` column disables range/arithmetic
operators, breaks sorting, and forces implicit conversions that kill indexes.

```sql
-- ❌ BAD  OrderDate VARCHAR(10),  Amount VARCHAR(20)
-- ✅ GOOD  OrderDate DATE,        Amount DECIMAL(12,2)
```

---

### Rule A13: Prefer Modern Temporal Types
**Severity**: Low | **Effort**: S | **Applies to**: SQL Server

Use `DATETIME2` (smaller, higher precision, wider range) instead of legacy `DATETIME`, and
`DATE`/`TIME` when you don't need both parts. (Postgres equivalent: `TIMESTAMPTZ` — see A9.)

---

### Rule A14: Avoid ENUM/SET for Mutable Domains
**Severity**: Medium | **Effort**: M | **Applies to**: MySQL

`ENUM`/`SET` bake the allowed values into the schema; adding a value requires an
`ALTER TABLE`. Use a lookup table with a foreign key for domains that change.

---

### Rule A15: Right-Size Numeric Types
**Severity**: Low | **Effort**: S | **Applies to**: All Platforms

Defaulting every integer to `BIGINT` or every string to `VARCHAR(255)` wastes storage,
memory, and index space. Size types to the real domain (e.g., `SMALLINT` for a status,
`TINYINT`/`INT` for counts).

---

## B. Schema Design Anti-Patterns (continued)

### Rule B12: Avoid Entity-Attribute-Value (EAV)
**Severity**: High | **Effort**: L | **Applies to**: All Platforms

A generic `(entity_id, attribute_name, value)` table destroys typing, constraints, and
query performance (every logical row needs N self-joins). Use real columns, or a typed
JSONB/document field for genuinely dynamic attributes (see B11).

---

### Rule B13: Declare Foreign Key Constraints, Not Just FK Columns
**Severity**: High | **Effort**: M | **Applies to**: All Relational

A column named `customer_id` with no `FOREIGN KEY` constraint allows orphan rows and hides
the relationship from tooling and the optimizer. Declare the constraint (or document why
it is deferred, e.g., sharding).

---

### Rule B14: No Comma-Separated Values in a Single Column ("Jaywalking")
**Severity**: High | **Effort**: L | **Applies to**: All Platforms

Storing `'1,5,9'` in a `tags` column prevents indexing, joins, and integrity checks and
forces string parsing. Use a junction table (relational) or a native array/sub-document
(Postgres array, Mongo array) with an appropriate index.

---

### Rule B15: Enforce Domain Rules with CHECK Constraints
**Severity**: Medium | **Effort**: S | **Applies to**: All Platforms

Validate ranges/allowed values in the database (`CHECK (status IN (...))`,
`CHECK (price >= 0)`) rather than trusting the application. MongoDB: use schema validation
rules. This is the DB-side complement to Rule B3/B4.

---

### Rule B16: Avoid Over-Indexing
**Severity**: Medium | **Effort**: M | **Applies to**: All Platforms

Every index must be maintained on every INSERT/UPDATE/DELETE. Redundant or unused indexes
(e.g., a single-column index that is a left-prefix of a composite one) slow writes and
waste space. Audit with `sys.dm_db_index_usage_stats` (SQL Server),
`pg_stat_user_indexes` (Postgres), `$indexStats` (Mongo). Balances Rules B6/B7.

---

### Rule B17: Avoid Excessively Wide Tables
**Severity**: Medium | **Effort**: L | **Applies to**: All Platforms

Tables with dozens of columns (especially many nullable ones) signal missing
normalization, cause page/row-size pressure, and make `SELECT *` even costlier. Split into
related tables or move rarely-used columns off-row.

---

### Rule B18: Use InnoDB + utf8mb4
**Severity**: High | **Effort**: M | **Applies to**: MySQL

MyISAM has no transactions, no foreign keys, and table-level locking — use **InnoDB**.
The legacy `utf8` charset is only 3-byte and cannot store emoji/supplementary characters —
use **utf8mb4**. Mismatched charsets also break index use on joins (see C23).

---

## C. Query Performance Anti-Patterns (continued)

### Rule C26: Avoid Implicit Data-Type Conversion (all platforms)
**Severity**: High | **Effort**: S | **Applies to**: All Platforms

Generalizes the Oracle-specific Rule C20. Comparing a column to a literal of a different
type (string-vs-number, `NVARCHAR`-vs-`VARCHAR`, date-vs-string) makes the engine wrap the
*column* in a conversion, disabling its index. Always match literal type and column
collation/type.

---

### Rule C27: Use EXISTS, Not COUNT(*), for Existence Checks
**Severity**: Medium | **Effort**: S | **Applies to**: All Platforms

`IF (SELECT COUNT(*) ...) > 0` scans all matching rows; `EXISTS` short-circuits on the
first match.

```sql
-- ❌ BAD   IF (SELECT COUNT(*) FROM Orders WHERE CustomerID = @id) > 0
-- ✅ GOOD  IF EXISTS (SELECT 1 FROM Orders WHERE CustomerID = @id)
```

---

### Rule C28: Don't Wrap Indexed Columns in ISNULL/COALESCE/CAST
**Severity**: High | **Effort**: S | **Applies to**: All Platforms

A specific, very common form of Rule C1. `WHERE ISNULL(col,0) = 0` or `WHERE CAST(col ...)`
is non-SARGable. Rewrite with `OR col IS NULL` / a computed+indexed column, or fix the type.

---

### Rule C29: Avoid Large or Variable-Length IN() Lists
**Severity**: Medium | **Effort**: M | **Applies to**: All Relational

Thousands of literals in `IN (...)` bloat the plan, cause hard-parse churn (new plan per
list length), and can hit parser limits. Load the values into a temp table / table-valued
parameter / `VALUES` list and JOIN.

---

### Rule C30: Avoid Catch-All "Kitchen Sink" Predicates
**Severity**: High | **Effort**: M | **Applies to**: SQL Server, Oracle, PostgreSQL

`WHERE (@p IS NULL OR Col = @p) AND (@q IS NULL OR Col2 = @q)` forces one plan to serve all
parameter combinations, usually a scan. Use dynamic SQL built with safe parameters, or
`OPTION (RECOMPILE)` (SQL Server) where justified.

---

### Rule C31: Avoid Nested Views (View-on-View)
**Severity**: Medium | **Effort**: M | **Applies to**: All Relational

Stacking views on views hides complexity and defeats the optimizer (it must expand and
often cannot prune columns/joins). Flatten critical paths into a single query or indexed/
materialized view.

---

### Rule C32: NOLOCK / READ UNCOMMITTED Is a Correctness Risk
**Severity**: High | **Effort**: S | **Applies to**: SQL Server

Expands Rule C19 with the correctness angle: `WITH (NOLOCK)` permits dirty reads, missing
rows, and double-counted rows — not just a "performance hint." Use `READ COMMITTED
SNAPSHOT` / proper isolation instead of sprinkling NOLOCK.

---

### Rule C33: Use SET NOCOUNT ON in Procedures
**Severity**: Low | **Effort**: S | **Applies to**: SQL Server

Without `SET NOCOUNT ON`, each statement sends a "n rows affected" message, adding network
chatter and occasionally confusing ORMs. Add it at the top of procedures/triggers.

---

### Rule C34: Avoid Accidental Cartesian Products
**Severity**: High | **Effort**: S | **Applies to**: All Relational

A missing or wrong join predicate (or a stray `CROSS JOIN`) multiplies row counts. Every
join should have a predicate linking the tables; verify row counts after adding joins.

---

## D. Code Quality Anti-Patterns (continued)

### Rule D8: Always Schema-Qualify Object Names
**Severity**: Medium | **Effort**: S | **Applies to**: SQL Server, PostgreSQL, Oracle

Reference `dbo.Orders`, not `Orders`. Unqualified names trigger name-resolution overhead
and recompiles (SQL Server) and depend on `search_path` (Postgres), causing ambiguity.

---

### Rule D9: No Magic Numbers / Unexplained Literals
**Severity**: Low | **Effort**: S | **Applies to**: All Platforms

`WHERE Status = 3` is opaque. Use a lookup table, named constant, or at minimum a comment
explaining the value.

---

### Rule D10: Prefer CTEs Over Deeply Nested Subqueries
**Severity**: Low | **Effort**: M | **Applies to**: All Relational

Three-plus levels of nested derived tables are unreadable and hard to debug. Use named
CTEs (`WITH`). (Note the Postgres pre-12 CTE materialization caveat.)

---

## E. Security Anti-Patterns (continued)

### Rule E3: Apply Least Privilege
**Severity**: Critical | **Effort**: M | **Applies to**: All Platforms

Application accounts running as `db_owner`/`sysadmin`/`SUPER`/`SUPERUSER` turn any SQL bug
into a full compromise. Grant only the needed object-level privileges.

---

### Rule E4: Never Store Secrets or PII in Plaintext
**Severity**: Critical | **Effort**: L | **Applies to**: All Platforms

Passwords must be salted+hashed; sensitive PII (PAN, national IDs) should be encrypted
(column-level/TDE/Always Encrypted). Plaintext secrets in tables or code are a breach
waiting to happen (complements E2).

---

### Rule E5: Disable Dangerous Surface Area
**Severity**: High | **Effort**: S | **Applies to**: SQL Server

Leaving `xp_cmdshell`, `OPENROWSET`/`OPENQUERY` ad-hoc access, or CLR enabled widens the
attack surface. Disable unless there is an approved, audited need.

---

### Rule E6: Parameterize Identifiers Too
**Severity**: High | **Effort**: M | **Applies to**: All Platforms

`sp_executesql` protects *values* but not *object names*. Concatenating a user-supplied
table/column name is still injectable — whitelist identifiers or wrap with `QUOTENAME()`
(SQL Server) / `quote_ident()` (Postgres).

---

## I. Transaction & Concurrency Anti-Patterns (new category)

### Rule I1: No Long-Running or User-Interactive Transactions
**Severity**: High | **Effort**: M | **Applies to**: All Platforms

Opening a transaction, then waiting on user input, HTTP calls, or row-by-row loops holds
locks and bloats logs/undo. Keep transactions short; do external work outside them.

---

### Rule I2: Wrap Multi-Statement Units of Work in a Transaction
**Severity**: High | **Effort**: M | **Applies to**: All Platforms

Related writes (e.g., insert order + decrement stock) executed without a transaction leave
partial state on failure. Wrap them in an explicit transaction with error handling (see J1).

---

### Rule I3: Choose the Correct Isolation Level Deliberately
**Severity**: Medium | **Effort**: M | **Applies to**: All Platforms

Relying on the default without thought causes either lost updates (too loose) or blocking/
deadlocks (too strict). Pick per workload; prefer snapshot/MVCC-based isolation for
read-heavy OLTP.

---

## J. Error Handling & Procedural Anti-Patterns (new category)

### Rule J1: Use Structured Error Handling
**Severity**: High | **Effort**: M | **Applies to**: SQL Server, Oracle, PostgreSQL

Procedural code without error handling leaves transactions open and errors unlogged. Use
`TRY...CATCH` + `XACT_STATE()` (SQL Server), `EXCEPTION WHEN` (Oracle / PL/pgSQL) with
rollback and re-raise.

---

### Rule J2: Never Silently Swallow Exceptions
**Severity**: High | **Effort**: S | **Applies to**: Oracle, PostgreSQL

`EXCEPTION WHEN OTHERS THEN NULL;` hides failures and corrupts data silently. Always log
and re-raise unless a specific, documented exception is being handled.

---

## G. Platform-Specific Anti-Patterns (continued)

### Rule G7: Missing Partial / Covering Indexes & Stale Statistics
**Severity**: Medium | **Effort**: M | **Applies to**: PostgreSQL

Use **partial indexes** (`WHERE is_active`) for selective predicates and **covering
indexes** (`INCLUDE`) to avoid heap fetches. Ensure autovacuum/`ANALYZE` keeps statistics
fresh — stale stats produce bad plans.

---

### Rule G8: ROWNUM Pagination Pitfall
**Severity**: Medium | **Effort**: S | **Applies to**: Oracle

`WHERE ROWNUM <= 10 ORDER BY ...` filters *before* sorting, returning the wrong rows. Use
`OFFSET ... FETCH` (12c+) or an analytic/`ROW_NUMBER()` subquery, with keyset pagination for
deep pages (see C8).

---

### Rule G9: Unbounded Document / Array Growth
**Severity**: High | **Effort**: L | **Applies to**: MongoDB

Documents that grow forever (e.g., appending every event to one array) hit the 16 MB limit
and cause constant re-allocation. Use the bucket pattern or a separate collection.

---

### Rule G10: Avoid $where and Server-Side JavaScript
**Severity**: High | **Effort**: M | **Applies to**: MongoDB

`$where`/`$function` run interpreted JS per document — no index use and an injection
vector. Express the predicate with native query operators.

---

## Suggested Rule-Metadata Schema (for automated detection & effort estimation)

To make detection and man-day estimates repeatable, store each rule with machine-readable
metadata rather than prose alone:

```yaml
- id: C1
  title: Avoid Functions on Columns in Predicates
  severity: critical          # critical | high | medium | low
  platforms: [sqlserver, oracle, mysql, postgres, mongodb]
  category: performance
  detection:                  # heuristics a scanner/LLM can apply
    - "function call on a column inside WHERE/ON/HAVING"
    - regex: "(WHERE|AND|ON)\\s+\\w+\\s*\\([^)]*\\b{col}\\b"
  remediation_effort: S       # S < 0.5d | M 0.5-2d | L > 2d
  false_positives:
    - "function applied to a literal/parameter, not a column"
  references: [rules-sql-anti-pattern.md#rule-28]
```

A `rules.yaml` (or JSON) companion lets the prompt emit a findings table keyed by `id`,
auto-sum `remediation_effort`, and suppress `false_positives` consistently.
