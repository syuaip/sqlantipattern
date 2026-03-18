# PostgreSQL Query Anti-Pattern Rules

PostgreSQL is a powerful and flexible database, but its "everything-is-possible" nature makes it easy to fall into performance traps. As of 2026, many classic anti-patterns still exist alongside newer ones related to JSONB and modern cloud environments.

Here is a categorized list of PostgreSQL query anti-patterns to avoid.

---

## 1. Data Retrieval & Filtering

These anti-patterns often cause unnecessary I/O and prevent the query planner from using indexes.

- **SELECT * in Production:**
  - **The Trap:** Fetching every column increases network traffic and memory usage.
  - **The Fix:** Explicitly name the columns you need. This also makes your code resilient to schema changes.

- **Functions on Indexed Columns:**
  - **The Trap:** `WHERE date_trunc('day', created_at) = '2026-03-12'` prevents the use of a standard index on `created_at`.
  - **The Fix:** Compare the column directly to a range: `WHERE created_at >= '2026-03-12' AND created_at < '2026-03-13'`.

- **Leading Wildcards in LIKE:**
  - **The Trap:** `LIKE '%search%'` forces a full table scan.
  - **The Fix:** Use `LIKE 'search%'` (trailing wildcard) or implement a **GIN index** with the `pg_trgm` extension for fuzzy searches.

- **NOT IN with Subqueries:**
  - **The Trap:** If the subquery returns a single NULL, the entire `NOT IN` result becomes empty. It is also often slower than alternatives.
  - **The Fix:** Use `NOT EXISTS` or a `LEFT JOIN ... WHERE ... IS NULL`.

---

## 2. Join & Subquery Inefficiency

- **The N+1 Query Pattern:**
  - **The Trap:** Fetching a list of records and then running a separate query for each record to get related data (common in ORMs).
  - **The Fix:** Use a single `JOIN` or a `CTE` to fetch all data in one trip.

- **Correlated Subqueries in SELECT:**
  - **The Trap:** Running a subquery for every row in the result set (e.g., `SELECT name, (SELECT count(*) FROM orders WHERE user_id = u.id) FROM users u`).
  - **The Fix:** Use a `LEFT JOIN` with a `GROUP BY` or a Window Function.

- **Redundant DISTINCT:**
  - **The Trap:** Using `DISTINCT` to "fix" a bad join that is duplicating rows.
  - **The Fix:** Fix the join logic (e.g., use `EXISTS` instead of a join if you only need to check for presence).

---

## 3. Schema & Data Type Mistakes

- **Using UUIDv4 as a Primary Key:**
  - **The Trap:** UUIDv4 is completely random, leading to "index fragmentation" and heavy I/O as new rows are inserted in random locations.
  - **The Fix:** Use **UUIDv7** (which is time-ordered) or `BIGINT` with an `IDENTITY` column.

- **The "Text" Trap (CHAR(n) or VARCHAR(n)):**
  - **The Trap:** Using `CHAR(n)` (which pads with spaces) or arbitrary `VARCHAR(255)` limits based on old habits from other databases.
  - **The Fix:** Use the `TEXT` type. In Postgres, there is no performance difference between `VARCHAR` and `TEXT`, but `TEXT` avoids unnecessary length constraints.

- **Storing Timestamps without Time Zones:**
  - **The Trap:** Using `TIMESTAMP` instead of `TIMESTAMPTZ`.
  - **The Fix:** Always use `TIMESTAMPTZ` to ensure the database handles UTC conversions and daylight savings correctly.

---

## 4. Modern & Advanced Anti-patterns

- **Over-reliance on JSONB for Relational Data:**
  - **The Trap:** Storing everything in a single JSONB blob. You lose strict typing, constraints, and the query planner's ability to use statistics effectively.
  - **The Fix:** Use standard columns for stable data; use JSONB only for truly dynamic or unstructured data.

- **Unbounded OFFSET Pagination:**
  - **The Trap:** `LIMIT 10 OFFSET 1000000` requires Postgres to scan and discard a million rows before returning ten.
  - **The Fix:** Use **Cursor-based pagination** (filtering by the last seen ID: `WHERE id > last_id LIMIT 10`).

- **Mixing OR across different columns:**
  - **The Trap:** `WHERE email = 'x' OR username = 'y'` often forces a sequential scan even if both columns are indexed.
  - **The Fix:** Use `UNION` to combine two indexed queries.

---

## How to Detect These

The best tool for catching these is the `EXPLAIN` command.
