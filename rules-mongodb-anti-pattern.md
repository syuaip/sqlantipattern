# MongoDB Query Anti-Pattern Rules

MongoDB is a powerful NoSQL database, but its flexibility is a double-edged sword. Because it doesn't enforce a schema by default, it's easy to write queries that work fine on small datasets but collapse under production loads.

Here are the most common MongoDB query anti-patterns with "Bad" vs. "Good" examples.

---

## 1. The "Case-Insensitive" Regex Trap

- **The Anti-pattern:** Using the `i` flag in a regular expression (e.g., `/^abc/i`). This prevents MongoDB from using a standard index effectively, often resulting in a collection scan.

- **Bad:**
```javascript
db.users.find({ username: /^johndoe$/i })
```

- **Good:** Store a normalized (lowercase) version of the field during insertion and query against that using a standard index.
```javascript
// Store: { username: "JohnDoe", username_low: "johndoe" }
db.users.find({ username_low: "johndoe" })
```

*Alternatively, use a **Collation** with strength 1 or 2 for case-insensitive indexing.*

---

## 2. Large Arrays and $unwind

- **The Anti-pattern:** Using `$unwind` on very large arrays early in an aggregation pipeline. This explodes the number of documents in memory and can hit the 100MB RAM limit for pipeline stages.

- **Bad:** Unwinding everything just to filter a few items.
```javascript
db.orders.aggregate([
  { $unwind: "$items" },
  { $match: { "items.status": "shipped" } }
])
```

- **Good:** Use `$filter` to reduce the array size first, or `$match` the document before unwinding.
```javascript
db.orders.aggregate([
  { $match: { "items.status": "shipped" } }, // Filter documents first
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

## 3. The Negative Query ($ne, $nin, $not)

- **The Anti-pattern:** Querying for what data *is not*. B-tree indexes are built to find what *is* there. Inequality operators usually force the engine to scan the entire index or the whole collection.

- **Bad:**
```javascript
db.products.find({ status: { $ne: "discontinued" } })
```

- **Good:** Query for the specific active statuses you want.
```javascript
db.products.find({ status: { $in: ["active", "out_of_stock", "preorder"] } })
```

---

## 4. Unbounded $lookup (The "Join" Abuse)

- **The Anti-pattern:** Using `$lookup` to join two massive collections without any initial filtering. This mimics relational behavior but is significantly slower in a document store.

- **Bad:**
```javascript
db.orders.aggregate([
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" } }
])
```

- **Good:** Always use a `$match` stage *before* the `$lookup` to minimize the number of joins being performed.
```javascript
db.orders.aggregate([
  { $match: { orderDate: { $gte: ISODate("2026-03-01") } } },
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" } }
])
```

---

## 5. Massive "In-Memory" Sorting

- **The Anti-pattern:** Sorting a result set on a field that isn't indexed. If the sort takes more than 32MB of RAM, MongoDB will throw an error unless you allow disk use (which is very slow).

- **Bad:**
```javascript
// 'score' is not indexed
db.players.find().sort({ score: -1 })
```

- **Good:** Create a **Compound Index** that covers both your filter and your sort (following the **ESR Rule**: Equal, Sort, Range).
```javascript
// Create index: { teamId: 1, score: -1 }
db.players.find({ teamId: "red_dragons" }).sort({ score: -1 })
```

---

## 6. Blind Projections

- **The Anti-pattern:** Returning the entire document when you only need one or two fields. This increases network overhead and prevents "Covered Queries" (queries where the index contains all the data needed).

- **Bad:**
```javascript
db.users.find({ email: "user@example.com" }) // Returns large profile pic, bio, etc.
```

- **Good:** Project only the necessary fields.
```javascript
db.users.find({ email: "user@example.com" }, { username: 1, _id: 0 })
```

---

## Pro-Tip: The .explain() Method

Always append `.explain("executionStats")` to your queries during development.

- **Look for COLLSCAN:** This means a full collection scan occurred (Bad).
- **Look for IXSCAN:** This means an index was used (Good).
