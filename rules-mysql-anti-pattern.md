# MySQL Query Anti-Pattern Rules

MySQL is the most popular open-source database, but its default behaviors (especially in older versions) and the way it handles indexes can lead to significant bottlenecks.

Here are the essential MySQL query anti-patterns to avoid for high-performance applications.

---

## 1. Indexing & SARGability

"SARGable" stands for **Search ARgumentable**, meaning the query can actually use an index.

- **OR Conditions on Different Columns:**
  - **The Trap:** `WHERE user_id = 10 OR email = 'test@example.com'`. MySQL often struggles to use two separate indexes in one query, often defaulting to a **Full Table Scan**.
  - **The Fix:** Use `UNION ALL` to combine two separate indexed queries.

- **Mathematical Operations on Columns:**
  - **The Trap:** `WHERE age + 1 > 18`. This prevents index usage on the `age` column.
  - **The Fix:** Move the math to the right side of the operator: `WHERE age > 17`.

- **The "Double Wildcard" Search:**
  - **The Trap:** `LIKE '%keyword%'`. Standard B-tree indexes cannot be used when a wildcard starts the string.
  - **The Fix:** Use a **FULLTEXT** index or an external search engine like Elasticsearch if prefix-matching (`keyword%`) isn't enough.

---

## 2. Join & Subquery Inefficiency

- **The IN (SELECT ...) Performance Hole:**
  - **The Trap:** In older MySQL versions (pre-5.7/8.0), `WHERE id IN (SELECT id FROM ...)` was often re-executed for every row of the outer query.
  - **The Fix:** Use a `JOIN` or `EXISTS`. While the modern optimizer is better, a `JOIN` is still generally more predictable.

- **Joining on Mismatched Collations:**
  - **The Trap:** Joining two tables where one is `utf8mb4_general_ci` and the other is `utf8mb4_unicode_ci`. MySQL cannot use indexes across different collations/charsets without converting them on the fly.
  - **The Fix:** Ensure all related columns share the exact same character set and collation.

---

## 3. Data Retrieval & Sorting

- **ORDER BY RAND():**
  - **The Trap:** `SELECT * FROM products ORDER BY RAND() LIMIT 1`. For a table with 1 million rows, MySQL generates 1 million random numbers, sorts them all, and then picks one.
  - **The Fix:** Generate a random ID in your application code and query that specific ID, or use a weighted offset.

- **The OFFSET Tax:**
  - **The Trap:** `LIMIT 100000, 10`. MySQL must read 100,010 rows and then throw away the first 100,000.
  - **The Fix:** Use "Deferred Joins" or Keyset Pagination (e.g., `WHERE id > last_seen_id LIMIT 10`).

---

## 4. Schema & Engine Traps

- **Using SELECT COUNT(*) on Large InnoDB Tables:**
  - **The Trap:** Unlike MyISAM, InnoDB does not store an internal row count. `COUNT(*)` without a `WHERE` clause requires a full scan of the smallest available index.
  - **The Fix:** If an exact count isn't needed, use `SHOW TABLE STATUS` or maintain a separate counter table.

- **Storing IP Addresses as Strings:**
  - **The Trap:** Storing `192.168.1.1` as a `VARCHAR(15)`. It wastes space and slows down searches.
  - **The Fix:** Use `INET6_ATON()` and `INET6_NTOA()` functions to store IPs as binary data (`VARBINARY(16)`), which is significantly faster and more compact.

---

## How to Audit Your MySQL Queries

MySQL provides a built-in tool to see exactly how it intends to run your query.

**Tip:** Use `EXPLAIN ANALYZE` (available in MySQL 8.0+). Unlike a regular `EXPLAIN`, this actually runs the query and shows you where the time was spent and how many rows were actually examined.
