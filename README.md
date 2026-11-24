# sqlantipattern

> A knowledge base + AI-agent playbook for detecting **SQL query and schema anti-patterns**
> across five database platforms — **SQL Server, Oracle, MySQL, PostgreSQL, and MongoDB**.

`sqlantipattern` turns a set of curated anti-pattern rules into a repeatable, AI-assisted
code review. You point a coding agent (e.g. [Kiro](https://kiro.dev)) at your `.sql` source,
load the rule files as detection knowledge, and the agent produces a prioritized findings
report with line numbers, severities, and remediation guidance.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [How it works](#how-it-works)
- [Repository structure](#repository-structure)
- [The rule knowledge base](#the-rule-knowledge-base)
- [Anti-pattern categories](#anti-pattern-categories)
- [Quick start](#quick-start)
- [The prompt playbook](#the-prompt-playbook)
- [Sample / demo assets](#sample--demo-assets)
- [Example output](#example-output)
- [Extending the knowledge base](#extending-the-knowledge-base)
- [Severity & remediation model](#severity--remediation-model)
- [FAQ](#faq)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

SQL anti-patterns — `SELECT *`, functions on indexed columns, missing primary keys,
row-by-row cursors, nullable foreign keys, dynamic SQL, and dozens more — quietly erode
**performance, correctness, security, and maintainability**. They're easy to introduce and
hard to catch in manual review, especially across a large codebase and multiple database
engines.

This project packages that review knowledge as **plain-text + Markdown rule files** that an
LLM coding agent can load and apply consistently. The result:

- **Repeatable reviews** — the same rules, every time, not reviewer memory.
- **Line-accurate findings** — each issue tied to a file and line number.
- **Cross-platform** — one workflow for SQL Server, Oracle, MySQL, PostgreSQL, and MongoDB.
- **Actionable** — findings come with severity, a "why it's bad" explanation, and a fix.

---

## How it works

```
┌──────────────────┐     ┌────────────────────┐     ┌─────────────────────┐
│  Rule files      │     │  Your .sql source  │     │  Coding agent       │
│  (this repo)     │ ──▶ │  (code to review)  │ ──▶ │  (Kiro / LLM)       │
└──────────────────┘     └────────────────────┘     └──────────┬──────────┘
        load as                 scan against                    │ produces
     detection rules             the rules                       ▼
                                                      ┌─────────────────────┐
                                                      │  Findings report    │
                                                      │  + remediation plan  │
                                                      │  (MD / HTML / CSV)   │
                                                      └─────────────────────┘
```

1. **Load** a rule file as the agent's detection knowledge.
2. **Scan** your `.sql` files against those rules.
3. **Report** findings with line numbers, grouped by severity.
4. **Plan** remediation prioritized by criticality and effort.
5. **Maintain** — ask the agent to improve the rules over time.

---

## Repository structure

| File | What it is |
|------|------------|
| **`rules-consolidated-query-anti-pattern.md`** | ⭐ **Start here.** A unified reference of all anti-patterns across the five platforms, organized by category (A–H) with severity, "applies to", and ❌ BAD / ✅ GOOD examples. |
| `rules-sql-anti-pattern.md` | SQL Server rule set — the most detailed (43 rules), each with description, "why it's bad", examples, and exceptions. |
| `rules-oracle-anti-pattern.md` | Oracle-specific rules (incl. `(+)` joins, `ROWNUM`, function-based indexes, implicit conversion). |
| `rules-mysql-anti-pattern.md` | MySQL-specific rules (incl. IP-as-binary, storage engine / charset notes). |
| `rules-postgres-anti-pattern.md` | PostgreSQL-specific rules (incl. `TEXT` vs `VARCHAR`, `TIMESTAMPTZ`, UUIDv7, JSONB). |
| `rules-mongodb-anti-pattern.md` | MongoDB document-model rules (projections, indexing, schema design). |
| `sql-anti-pattern.txt` | The original seed rule list (SQL Server, terse). Superseded by the `.md` files — kept for history. |
| `prompt samples.txt` | Copy-paste prompts that drive the agent through the load → analyze → plan → report → maintain workflow. |
| `Schema.sql` | A demo SQL Server e-commerce schema (used as a review target / fixture). |
| `bad-query-samples.sql` | A short, **deliberately bad** T-SQL script with labeled anti-patterns — great for testing the detector. |

> **Note:** `Schema.sql` and `bad-query-samples.sql` intentionally contain anti-patterns so
> you can see the detector fire. Don't use them as reference designs.

---

## The rule knowledge base

Every rule follows a consistent, LLM-friendly shape:

```markdown
### Rule C1: Avoid Functions on Columns in Predicates
**Severity**: Critical | **Applies to**: All Platforms

Never apply functions to columns in WHERE, JOIN, or ON clauses. This prevents index
usage and forces full table/collection scans (10–100× slower).

```sql
-- ❌ BAD
WHERE YEAR(OrderDate) = 2024

-- ✅ GOOD
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'
```
```

Each rule carries:
- **A stable ID** (e.g. `C1`) and a descriptive title.
- **Severity** — Critical / High / Medium / Low.
- **Applies to** — which platform(s) the rule is relevant for.
- **An explanation** of why the pattern is harmful.
- **❌ BAD / ✅ GOOD examples** in the relevant dialect.
- **Exceptions** — when the pattern is legitimately acceptable.

The **consolidated file** is the recommended detection source: it de-duplicates the
per-platform rules into one catalog and tags each with its applicable platforms, so the agent
can skip rules that don't apply to the dialect it's reviewing.

---

## Anti-pattern categories

The consolidated knowledge base organizes rules into these groups:

| # | Category | Examples |
|---|----------|----------|
| **A** | **Data Type** | `sql_variant`, over-using `NVARCHAR`, `VARCHAR(MAX)` misuse, fixed-length codes, `TIMESTAMPTZ`, IP-as-binary |
| **B** | **Schema Design** | missing primary key, composite PKs, nullable FKs, missing indexes, triggers, reserved words, unused tables, JSONB overuse |
| **C** | **Query Performance** | functions on columns, `SELECT *`, implicit joins, `NOT IN`/NULL trap, leading-wildcard `LIKE`, cursors / RBAR, pagination |
| **D** | **Code Quality** | unqualified names, unused params/variables, implicit `INSERT` column lists |
| **E** | **Security** | SQL injection, dynamic SQL, hardcoded credentials |
| **F** | **Maintainability** | meaningless names, undocumented complex logic |
| **G** | **Platform-Specific** | Oracle `(+)`, Postgres JSONB/UUID, MySQL engine/charset, Mongo projections |
| **H** | **Diagnostic Tools** | per-platform `EXPLAIN` / execution-plan / index-usage tooling |

---

## Quick start

### Prerequisites
- A coding agent that can read local files and follow multi-step prompts
  (e.g. [Kiro](https://kiro.dev), or any capable LLM IDE assistant).
- The `.sql` code you want to review, in a folder (referred to below as `source-code/`).

### Steps

```text
1. Clone this repo next to the code you want to review:
     git clone https://github.com/syuaip/sqlantipattern.git

2. In your agent, load the rules as detection knowledge:
     "Read rules-consolidated-query-anti-pattern.md and use the rules there
      for identifying SQL query anti-patterns."

3. Point it at your code:
     "Read all .sql files under source-code/ and list the anti-pattern behavior
      you find. List each finding with its file and line number."

4. Ask for a prioritized fix plan:
     "Suggest a remediation plan with priority based on criticality and effort."

5. Generate a report:
     "Create the report as a Markdown file named sql-anti-pattern-report.md."
```

See [`prompt samples.txt`](prompt%20samples.txt) for the full, copy-paste prompt sequence.

---

## The prompt playbook

`prompt samples.txt` drives the agent through a repeatable workflow:

1. **Load rules** — treat the rule file as the authoritative detection rule set.
2. **Analyze** — scan `.sql` files and list findings with line numbers.
3. **Prioritize** — produce a remediation plan ranked by criticality (and, ideally, effort).
4. **Report** — emit the results as Markdown (HTML or CSV also work well for PM hand-off).
5. **Maintain** — periodically ask the agent to review and improve the rule set itself,
   writing new rules back in Markdown format.

**Tips for reliable results**
- Ask the agent to **detect the SQL dialect per file first**, then apply only the rules whose
  "Applies to" includes that dialect.
- Require a **structured findings table**: `File | Line | Rule ID | Severity | Snippet | Why | Fix`.
- Ask for a **confidence level** per finding and to **respect each rule's exceptions** to keep
  false positives down.
- Keep the review **read-only** — the agent should analyze, not execute or modify, your SQL.

---

## Sample / demo assets

- **`bad-query-samples.sql`** — a compact T-SQL script whose comments label nine classic
  anti-patterns (dynamic SQL, `SELECT *`, cursor/RBAR, `SELECT` inside a `WHILE`, UDF in a
  predicate, `NOT IN` with a subquery, `<>`, leading-wildcard `LIKE`). Use it to sanity-check
  that your agent + rules are catching what they should.
- **`Schema.sql`** — a fuller SQL Server e-commerce schema (customers, products, orders,
  reviews, inventory) with seeded design anti-patterns, stored procedures, views, and
  triggers. Use it as a realistic review target.

---

## Example output

A typical findings table the agent produces:

| File | Line | Rule | Severity | Why | Fix |
|------|------|------|----------|-----|-----|
| `bad-query-samples.sql` | 41 | C1 — Function on column | Critical | UDF on a column in `WHERE` is non-SARGable → full scan | Pre-compute the value; filter a raw indexed column |
| `bad-query-samples.sql` | 43 | C7 — `NOT IN` subquery | High | Returns zero rows if any NULL exists; poor plan | Use `NOT EXISTS` / anti-join |
| `bad-query-samples.sql` | 57 | C31 — Leading-wildcard `LIKE` | High | `'%@gmail.com'` forces a full scan | Trailing wildcard / computed column / full-text index |
| `Schema.sql` | 113 | B4 — Nullable foreign key | High | Nullable FK weakens referential integrity | `NOT NULL` unless the relationship is truly optional |

…followed by a **remediation plan** that groups findings into priorities (quick wins first,
then critical/high by effort) with an estimated effort per group.

---

## Extending the knowledge base

The rules are meant to grow. To add or improve a rule:

1. **Pick the right category** (A–H) and assign the **next free ID** in that category.
2. **Follow the rule template** (severity, applies-to, description, ❌/✅ examples, exceptions).
3. **Document the exceptions / false positives** so the detector stays precise.
4. Prefer adding to **`rules-consolidated-query-anti-pattern.md`** (the source of truth); keep
   per-platform files in sync, or note the platform in the consolidated entry.

You can also let the agent help:

```text
"Review the rules in rules-consolidated-query-anti-pattern.md and propose new rules
 based on current best practices. For each, give the category, severity, platforms,
 a BAD/GOOD example, and its exceptions. Do not duplicate an existing rule ID."
```

> 💡 For automated detection and effort estimation, consider pairing the Markdown with a
> machine-readable `rules.yaml` (id, severity, platforms, category, detection heuristics,
> remediation effort, false positives). This lets tooling sum man-days and suppress known
> false positives consistently.

---

## Severity & remediation model

| Severity | Meaning | Typical action |
|----------|---------|----------------|
| **Critical** | Correctness/security risk or guaranteed scan at scale | Fix now |
| **High** | Significant performance or integrity impact | Fix this sprint |
| **Medium** | Noticeable inefficiency / maintainability cost | Schedule |
| **Low** | Minor / stylistic | Opportunistic |

A good remediation plan ranks **Critical-severity + low-effort "quick wins" first**, then
Critical/High regardless of effort, then the rest — with a note for any fix that needs a
**schema migration** or downtime.

---

## FAQ

**Does this execute my SQL or connect to my database?**
No. It's a **static, read-only** review of `.sql` text. The agent reads your files and the
rules; it doesn't run queries or alter anything.

**Which databases are supported?**
SQL Server, Oracle, MySQL, PostgreSQL, and MongoDB. The consolidated file tags each rule with
the platforms it applies to.

**Do I have to use Kiro?**
No — any coding agent/LLM assistant that can read local files and follow the prompt playbook
works. The prompts in `prompt samples.txt` are written generically.

**The agent flagged something that's actually fine. Why?**
Many rules have legitimate exceptions (e.g. `SELECT *` inside `EXISTS`, composite keys on
junction tables, triggers for audit logging). Make sure the agent is told to honor each
rule's exceptions, and consider adding/annotating the exception in the rule.

**Is `Schema.sql` a good schema to copy?**
No — it deliberately contains anti-patterns as a review target.

---

## Roadmap

- [ ] A machine-readable `rules.yaml` catalog to drive automated scanning + effort estimates.
- [ ] A labeled regression fixture (expected findings) to measure detector precision/recall.
- [ ] More rules for transactions/concurrency, error handling, and deeper security.
- [ ] Deprecate the legacy `sql-anti-pattern.txt` in favor of the consolidated Markdown.

---

## Contributing

Contributions are welcome! Please:
- Keep each rule in the standard template (severity, applies-to, examples, exceptions).
- Avoid duplicate rule IDs; add to the correct category.
- Include at least one ❌ BAD and one ✅ GOOD example in the relevant dialect.
- Update the consolidated file so it stays the single source of truth.

Open an issue to propose a new rule or discuss a change before a large PR.

---

## License

See the repository for license details. If no license file is present, treat the content as
"all rights reserved" by the repository owner until a license is added.

---

<sub>Built to make SQL reviews consistent, cross-platform, and actionable. ⭐ the repo if it
helps your team ship healthier databases.</sub>
