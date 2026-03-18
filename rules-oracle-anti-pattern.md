# Oracle SQL Anti-Pattern Rules

Oracle Database has a sophisticated optimizer, but it is highly sensitive to how SQL is written. Many anti-patterns that are "fine" in other databases can lead to severe performance degradation in Oracle due to how it handles row-level locking, memory (SGA/PGA), and index suppression.

Here are the primary Oracle SQL anti-patterns categorized by their impact.

---

## 1. Index Suppression (The Silent Killers)

These patterns prevent the Oracle Optimizer from using an index, forcing a costly **Full Table Scan (FTS)**.

- **Function Wrapping on Columns:**
  - **Anti-pattern:** `WHERE TRUNC(created_date) = TO_DATE('2026-01-01', 'YYYY-MM-DD')`
  - **The Fix:** Compare the column to a range so the index remains "visible":
    `WHERE created_date >= TO_DATE('2026-01-01', 'YYYY-MM-DD') AND created_at < TO_DATE('2026-01-02', 'YYYY-MM-DD')`

- **Implicit Type Conversion:**
  - **Anti-pattern:** Comparing a VARCHAR2 column to a numeric literal (e.g., `WHERE string_id = 123`). Oracle will internally wrap the column in a `TO_NUMBER()` function, disabling the index.
  - **The Fix:** Always match the data type of the literal to the column: `WHERE string_id = '123'`.

- **Searching for NULL in Standard Indexes:**
  - **Anti-pattern:** `WHERE status IS NULL`. In Oracle, standard B-tree indexes do not store entries where all indexed columns are null.
  - **The Fix:** Use a **Function-Based Index** (e.g., `NVL(column, 'N/A')`) or provide a default value for the column.

---

## 2. Efficiency & Resource Management

- **Using Literals instead of Bind Variables:**
  - **Anti-pattern:** `SELECT * FROM users WHERE id = 101`, then `SELECT * FROM users WHERE id = 102`.
  - **The Fix:** Use Bind Variables (`:id`). This allows Oracle to reuse the **Execution Plan** in the Library Cache, preventing "Hard Parses" which consume massive CPU.

- **Traditional Oracle Joins ((+) Syntax):**
  - **Anti-pattern:** Using the old `WHERE a.id = b.id(+)` syntax.
  - **The Fix:** Use **ANSI Joins** (`LEFT JOIN`). ANSI joins are easier to read, less prone to logic errors in complex queries, and are the standard for modern Oracle versions (19c/21c/26ai).

- **UNION vs. UNION ALL:**
  - **Anti-pattern:** Using `UNION` by default. `UNION` performs a distinct sort to remove duplicates, which is memory-intensive.
  - **The Fix:** Use `UNION ALL` unless you specifically need to filter out duplicate rows.

---

## 3. Large Data & Pagination

- **High-Offset Pagination:**
  - **Anti-pattern:** Using `OFFSET 10000 ROWS FETCH NEXT 10 ROWS ONLY`. Oracle still has to process the first 10,000 rows before giving you the 10 you want.
  - **The Fix:** Use **Keyset Pagination** (e.g., `WHERE id > :last_seen_id ORDER BY id FETCH FIRST 10 ROWS ONLY`).

- **The DISTINCT Crutch:**
  - **Anti-pattern:** Adding `DISTINCT` to a query because a `JOIN` is producing duplicate rows.
  - **The Fix:** Investigate the join logic. Usually, a `WHERE EXISTS` subquery is what you actually need and is far more efficient than fetching duplicates and then sorting them away.

---

## 4. PL/SQL Specific Anti-patterns

- **Row-by-Row Processing ("Slow-by-Slow"):**
  - **Anti-pattern:** Using a `FOR` loop in PL/SQL to update or insert records one at a time.
  - **The Fix:** Use **Bulk Collect** and **FORALL**. This reduces the "context switching" between the PL/SQL engine and the SQL engine, which is one of the most common causes of slow Oracle applications.

---

## Pro-Tip: The "Explain Plan"

In Oracle, you can always check if you've fallen into these traps by running:

```sql
EXPLAIN PLAN FOR [Your Query];
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Look for **"TABLE ACCESS FULL"** — if you see that on a large table, you likely have an index suppression anti-pattern.
