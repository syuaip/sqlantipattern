# SQL Anti-Pattern Rules

## Table of Contents
- [Data Type Anti-Patterns](#data-type-anti-patterns)
- [Schema Design Anti-Patterns](#schema-design-anti-patterns)
- [Query Performance Anti-Patterns](#query-performance-anti-patterns)
- [Code Quality Anti-Patterns](#code-quality-anti-patterns)
- [Security Anti-Patterns](#security-anti-patterns)
- [Maintainability Anti-Patterns](#maintainability-anti-patterns)

---

## Data Type Anti-Patterns

### Rule 1: Avoid sql_variant Data Type
**Severity**: Medium | **Category**: Data Type

**Description**: Using `sql_variant` data type reduces type safety and query performance.

**Why it's bad**:
- Loss of type safety and compile-time checking
- Increased storage overhead (additional 12-16 bytes per value)
- Cannot be used in indexes, computed columns, or constraints
- Requires explicit casting for operations
- Poor query optimizer performance

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Products (
    ProductID INT,
    AttributeValue sql_variant  -- Can store any type
);

-- ✅ GOOD
CREATE TABLE Products (
    ProductID INT,
    AttributeValue NVARCHAR(500)  -- Explicit type
);
-- Or use proper normalization with typed columns
```

**Exceptions**: None recommended. Use proper table design instead.

---

### Rule 2: Minimize Unicode Data Types (NCHAR/NVARCHAR)
**Severity**: Medium | **Category**: Data Type | **Impact**: Storage

**Description**: Unicode data types (NCHAR, NVARCHAR) consume twice the storage space of ASCII types (CHAR, VARCHAR).

**Why it's bad**:
- 2x storage consumption (2 bytes per character vs 1 byte)
- Increased memory usage for query processing
- Slower string operations
- Higher backup/restore times
- Increased network bandwidth

**Example**:
```sql
-- ❌ BAD (if data is ASCII-only)
CREATE TABLE Customers (
    Email NVARCHAR(100),      -- 200 bytes
    Phone NVARCHAR(20),       -- 40 bytes
    PostalCode NVARCHAR(10)   -- 20 bytes
);

-- ✅ GOOD
CREATE TABLE Customers (
    Email VARCHAR(100),       -- 100 bytes
    Phone VARCHAR(20),        -- 20 bytes
    PostalCode VARCHAR(10),   -- 10 bytes
    Comments NVARCHAR(MAX)    -- Only for international content
);
```

**When to use NVARCHAR**:
- User-generated content (reviews, comments)
- International names and addresses
- Multi-language support requirements
- Data containing non-ASCII characters (Chinese, Arabic, emoji, etc.)

---

### Rule 3: Avoid Single BIT Columns
**Severity**: Low | **Category**: Data Type | **Impact**: Storage

**Description**: Using a single BIT column wastes storage. SQL Server stores up to 8 BIT columns in 1 byte.

**Why it's bad**:
- A single BIT column consumes 1 full byte
- Inefficient storage utilization
- No performance benefit over TINYINT

**Example**:
```sql
-- ❌ BAD (wastes 7 bits)
CREATE TABLE Orders (
    OrderID INT,
    IsActive BIT  -- Uses 1 byte for 1 bit
);

-- ✅ GOOD (if you have multiple flags)
CREATE TABLE Orders (
    OrderID INT,
    IsActive BIT,
    IsShipped BIT,
    IsPaid BIT,
    IsRefunded BIT  -- All 4 use 1 byte total
);

-- ✅ ALTERNATIVE (for single flag)
CREATE TABLE Orders (
    OrderID INT,
    Status TINYINT  -- 0=Inactive, 1=Active (same 1 byte)
);
```

---

### Rule 4: Use VARCHAR(MAX) Only for Large Data
**Severity**: Medium | **Category**: Data Type | **Impact**: Performance

**Description**: VARCHAR(MAX) should only be used when data length exceeds 8000 bytes.

**Why it's bad**:
- Stored off-row (separate pages) causing extra I/O
- Cannot be used in indexes (max 900 bytes for index key)
- Slower sorting and comparison operations
- Increased tempdb usage
- Cannot be used in certain operations (e.g., GROUP BY in older versions)

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Products (
    ProductName VARCHAR(MAX),     -- Overkill for names
    Description VARCHAR(MAX),     -- Might be justified
    SKU VARCHAR(MAX)              -- Definitely overkill
);

-- ✅ GOOD
CREATE TABLE Products (
    ProductName VARCHAR(200),     -- Reasonable limit
    Description VARCHAR(MAX),     -- OK for long text
    SKU VARCHAR(50)               -- Appropriate size
);
```

**Guidelines**:
- Use VARCHAR(n) where n ≤ 8000 when possible
- Reserve VARCHAR(MAX) for truly large text (articles, documents)
- Consider TEXT/BLOB storage for very large content

---

### Rule 5: Use Fixed-Length Types for Small Data
**Severity**: Low | **Category**: Data Type | **Impact**: Performance

**Description**: For data consistently less than 4 characters, use CHAR/NCHAR instead of VARCHAR/NVARCHAR.

**Why it's bad**:
- VARCHAR adds 2-byte length prefix overhead
- For small strings, CHAR is more efficient
- Better memory alignment and cache performance

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Countries (
    CountryCode VARCHAR(2),    -- 'US', 'UK' - always 2 chars
    CurrencyCode VARCHAR(3),   -- 'USD', 'EUR' - always 3 chars
    Status VARCHAR(1)          -- 'A', 'I' - always 1 char
);

-- ✅ GOOD
CREATE TABLE Countries (
    CountryCode CHAR(2),       -- Fixed 2 bytes
    CurrencyCode CHAR(3),      -- Fixed 3 bytes
    Status CHAR(1)             -- Fixed 1 byte
);
```

**When to use CHAR**:
- Country codes (ISO 2-letter codes)
- Currency codes (ISO 3-letter codes)
- Status flags (single character)
- Fixed-format codes

---

## Schema Design Anti-Patterns

### Rule 6: Every Table Must Have a Primary Key
**Severity**: Critical | **Category**: Schema Design

**Description**: All tables must have a unique, unchangeable primary key.

**Why it's bad**:
- No way to uniquely identify rows
- Cannot establish foreign key relationships
- Duplicate rows possible
- Poor query performance (no clustered index by default)
- Data integrity issues

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Orders (
    OrderDate DATETIME,
    CustomerName VARCHAR(100),
    Amount DECIMAL(10,2)
    -- No primary key!
);

-- ✅ GOOD
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    OrderDate DATETIME NOT NULL,
    CustomerName VARCHAR(100) NOT NULL,
    Amount DECIMAL(10,2) NOT NULL
);
```

**Requirements**:
- Must be unique
- Must be unchangeable (immutable)
- Should be non-null
- Should be simple (prefer single column)

---

### Rule 7: Prefer Single-Column Primary Keys
**Severity**: Medium | **Category**: Schema Design

**Description**: Primary keys should be a single column when possible. Composite keys increase complexity.

**Why it's bad**:
- Larger index size (multiple columns)
- More complex foreign key relationships
- Slower join operations
- More difficult to reference in application code
- Increased storage for foreign keys

**Example**:
```sql
-- ❌ BAD (unless truly necessary)
CREATE TABLE OrderItems (
    OrderID INT,
    ProductID INT,
    LineNumber INT,
    Quantity INT,
    PRIMARY KEY (OrderID, ProductID, LineNumber)  -- Composite key
);

-- ✅ GOOD
CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate key
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    LineNumber INT NOT NULL,
    Quantity INT NOT NULL,
    UNIQUE (OrderID, ProductID, LineNumber),    -- Natural key as unique constraint
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
```

**Exceptions**:
- Junction/bridge tables in many-to-many relationships
- When composite key truly represents the natural identifier
- Legacy systems where refactoring is not feasible

---

### Rule 8: Use Appropriate Primary Key Data Types
**Severity**: Medium | **Category**: Schema Design

**Description**: Choose primary key data types based on requirements. UNIQUEIDENTIFIER (GUID) is not always the best choice.

**Why UNIQUEIDENTIFIER can be bad**:
- 16 bytes vs 4 bytes (INT) or 8 bytes (BIGINT)
- Random values cause index fragmentation
- Slower joins and lookups
- Larger indexes and foreign keys
- Not human-readable

**Example**:
```sql
-- ❌ QUESTIONABLE (for single-database systems)
CREATE TABLE Products (
    ProductID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ProductName VARCHAR(100)
);

-- ✅ GOOD (for single database)
CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName VARCHAR(100)
);

-- ✅ GOOD (for distributed systems)
CREATE TABLE Products (
    ProductID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),  -- Less fragmentation
    ProductName VARCHAR(100)
);
```

**When to use each type**:

| Type | Use Case | Pros | Cons |
|------|----------|------|------|
| INT | Single database, < 2B rows | Small, fast, sequential | Limited range |
| BIGINT | Single database, > 2B rows | Large range, fast | 8 bytes |
| UNIQUEIDENTIFIER | Distributed systems, merge replication | Globally unique | Large, fragmentation |
| VARCHAR | Natural keys (rare) | Human-readable | Variable size, slower |

---

### Rule 9: Use Proper Data Types for XML
**Severity**: Medium | **Category**: Data Type

**Description**: Always use the XML data type for XML data, not VARCHAR/NVARCHAR.

**Why it's bad**:
- No schema validation
- No XML indexing capabilities
- No XQuery support
- Larger storage (no compression)
- No type safety

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Documents (
    DocumentID INT PRIMARY KEY,
    XmlContent NVARCHAR(MAX)  -- Stored as text
);

-- ✅ GOOD
CREATE TABLE Documents (
    DocumentID INT PRIMARY KEY,
    XmlContent XML  -- Proper XML type
);

-- ✅ EVEN BETTER (with schema validation)
CREATE XML SCHEMA COLLECTION DocumentSchema AS 
'<schema xmlns="http://www.w3.org/2001/XMLSchema">
  <element name="document">
    <complexType>
      <sequence>
        <element name="title" type="string"/>
        <element name="content" type="string"/>
      </sequence>
    </complexType>
  </element>
</schema>';

CREATE TABLE Documents (
    DocumentID INT PRIMARY KEY,
    XmlContent XML(DocumentSchema)  -- With validation
);
```

**Benefits of XML type**:
- Built-in validation
- XQuery support
- XML indexes (PATH, VALUE, PROPERTY)
- Automatic compression
- Type safety

---

### Rule 10: Minimize Nullable Columns
**Severity**: Medium | **Category**: Schema Design

**Description**: Columns should be NOT NULL by default. Use NULL only when truly optional.

**Why it's bad**:
- Three-valued logic complexity (TRUE, FALSE, NULL)
- Index inefficiency (NULL values may not be indexed)
- Increased storage overhead
- More complex query logic (COALESCE, ISNULL)
- Potential for unexpected behavior

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50) NULL,      -- Should be required
    LastName VARCHAR(50) NULL,       -- Should be required
    Email VARCHAR(100) NULL,         -- Should be required
    MiddleName VARCHAR(50) NULL,     -- OK to be NULL
    PhoneExtension VARCHAR(10) NULL  -- OK to be NULL
);

-- ✅ GOOD
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    MiddleName VARCHAR(50) NULL,     -- Truly optional
    PhoneExtension VARCHAR(10) NULL  -- Truly optional
);
```

**Guidelines**:
- Default to NOT NULL
- Use NULL only for truly optional data
- Document why a column is nullable
- Consider using default values instead of NULL

---

### Rule 11: Foreign Key Columns Must Be NOT NULL
**Severity**: High | **Category**: Schema Design

**Description**: Foreign key columns should be NOT NULL to maintain referential integrity.

**Why it's bad**:
- Breaks referential integrity (orphaned relationships)
- Complicates join logic
- Ambiguous meaning (no relationship vs unknown relationship)
- Query performance issues

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NULL,  -- Nullable foreign key
    OrderDate DATETIME NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- ✅ GOOD
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,  -- Required relationship
    OrderDate DATETIME NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- ✅ ACCEPTABLE (for optional relationships)
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    ReferredByCustomerID INT NULL,  -- Optional referral
    OrderDate DATETIME NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (ReferredByCustomerID) REFERENCES Customers(CustomerID)
);
```

**Exception**: Optional relationships where NULL explicitly means "no relationship"

---

### Rule 12: Indexed Columns Should Be NOT NULL
**Severity**: Medium | **Category**: Schema Design

**Description**: Columns used in WHERE clauses and indexes should be NOT NULL.

**Why it's bad**:
- NULL values may not be indexed (database-dependent)
- Requires special NULL handling in queries
- Slower query performance
- More complex execution plans

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    CategoryID INT NULL,  -- Used in WHERE clauses
    SKU VARCHAR(50) NULL, -- Used for lookups
    Price DECIMAL(10,2) NULL
);
CREATE INDEX IX_Products_Category ON Products(CategoryID);

-- ✅ GOOD
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    CategoryID INT NOT NULL,  -- Always has a category
    SKU VARCHAR(50) NOT NULL UNIQUE,  -- Always has SKU
    Price DECIMAL(10,2) NOT NULL,
    DiscountPrice DECIMAL(10,2) NULL  -- Optional discount
);
CREATE INDEX IX_Products_Category ON Products(CategoryID);
```

---

### Rule 13: Avoid Triggers When Possible
**Severity**: High | **Category**: Schema Design | **Impact**: Maintainability

**Description**: Triggers create hidden logic that's difficult to debug and maintain.

**Why it's bad**:
- Hidden business logic (not visible in application code)
- Difficult to debug and trace
- Performance overhead (fires on every operation)
- Can cause unexpected side effects
- Recursive trigger issues
- Complicates testing

**Example**:
```sql
-- ❌ BAD
CREATE TRIGGER trg_UpdateInventory
ON OrderItems
AFTER INSERT
AS
BEGIN
    UPDATE Products
    SET StockQuantity = StockQuantity - i.Quantity
    FROM Products p
    INNER JOIN inserted i ON p.ProductID = i.ProductID;
END;

-- ✅ GOOD (explicit stored procedure)
CREATE PROCEDURE usp_CreateOrderItem
    @OrderID INT,
    @ProductID INT,
    @Quantity INT
AS
BEGIN
    BEGIN TRANSACTION;
    
    -- Insert order item
    INSERT INTO OrderItems (OrderID, ProductID, Quantity)
    VALUES (@OrderID, @ProductID, @Quantity);
    
    -- Update inventory (explicit and visible)
    UPDATE Products
    SET StockQuantity = StockQuantity - @Quantity
    WHERE ProductID = @ProductID;
    
    COMMIT TRANSACTION;
END;
```

**When triggers are acceptable**:
- Audit logging (with DBA approval)
- Enforcing complex business rules that cannot be done with constraints
- Maintaining denormalized data (with caution)
- Legacy systems where refactoring is not feasible

---

### Rule 14: Avoid SQL Reserved Words for Names
**Severity**: Medium | **Category**: Naming

**Description**: Never use SQL reserved words as table or column names.

**Why it's bad**:
- Requires delimiters (brackets, quotes) everywhere
- Confusing for developers
- Syntax errors in queries
- Portability issues across databases

**Example**:
```sql
-- ❌ BAD
CREATE TABLE [Order] (  -- 'Order' is reserved
    [Select] INT,       -- 'Select' is reserved
    [From] VARCHAR(50), -- 'From' is reserved
    [Where] INT         -- 'Where' is reserved
);

-- ✅ GOOD
CREATE TABLE Orders (
    OrderID INT,
    CustomerName VARCHAR(50),
    ShipToLocation VARCHAR(100)
);
```

**Common reserved words to avoid**:
- SELECT, INSERT, UPDATE, DELETE
- FROM, WHERE, JOIN, ON
- TABLE, VIEW, INDEX
- USER, ROLE, GRANT
- ORDER, GROUP, HAVING

---

### Rule 15: Every Table Must Have Indexes
**Severity**: Critical | **Category**: Performance

**Description**: Tables without indexes cause full table scans and poor performance.

**Why it's bad**:
- Full table scans on every query
- Exponentially slower as data grows
- High CPU and I/O usage
- Locks entire table during scans
- Poor user experience

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,  -- Only clustered index
    Email VARCHAR(100),
    LastName VARCHAR(50),
    City VARCHAR(50)
    -- No additional indexes!
);

-- ✅ GOOD
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Email VARCHAR(100) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    City VARCHAR(50) NOT NULL
);

-- Add indexes for common queries
CREATE UNIQUE INDEX IX_Customers_Email ON Customers(Email);
CREATE INDEX IX_Customers_LastName ON Customers(LastName);
CREATE INDEX IX_Customers_City ON Customers(City);
```

**Index guidelines**:
- Primary key creates clustered index automatically
- Add indexes on foreign keys
- Add indexes on columns in WHERE clauses
- Add indexes on columns in JOIN conditions
- Add indexes on columns in ORDER BY clauses
- Don't over-index (impacts INSERT/UPDATE performance)

---

### Rule 16: Index Columns Used in WHERE Clauses
**Severity**: High | **Category**: Performance

**Description**: Columns frequently used in WHERE clauses must have supporting indexes.

**Why it's bad**:
- Full table scans
- Slow query performance
- High I/O and CPU usage
- Poor scalability

**Example**:
```sql
-- ❌ BAD
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    Status VARCHAR(20) NOT NULL
);
-- No indexes on CustomerID, OrderDate, or Status!

-- Common query (will be slow):
SELECT * FROM Orders 
WHERE CustomerID = 12345 
  AND OrderDate >= '2024-01-01'
  AND Status = 'Pending';

-- ✅ GOOD
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    Status VARCHAR(20) NOT NULL
);

-- Add covering index for common query pattern
CREATE INDEX IX_Orders_Customer_Date_Status 
ON Orders(CustomerID, OrderDate, Status);
```

**Index design tips**:
- Most selective column first
- Include columns in SELECT (covering index)
- Consider filtered indexes for specific values
- Monitor index usage with DMVs

---

### Rule 17: Remove Unused Tables
**Severity**: Low | **Category**: Maintainability

**Description**: Tables defined in DDL but never used in queries should be removed.

**Why it's bad**:
- Wasted storage space
- Backup/restore overhead
- Maintenance overhead
- Confusing schema
- Security risk (forgotten data)

**Example**:
```sql
-- ❌ BAD (table exists but never queried)
CREATE TABLE TempCalculations (
    ID INT PRIMARY KEY,
    Value DECIMAL(10,2),
    CreatedDate DATETIME
);
-- Created 2 years ago, never used

-- ✅ GOOD
-- Drop unused tables after verification
DROP TABLE TempCalculations;
```

**How to identify**:
- Query execution logs
- Application code analysis
- Database monitoring tools
- DMV queries for table access

---

## Query Performance Anti-Patterns

### Rule 18: Always Use Explicit JOIN Syntax
**Severity**: High | **Category**: Query Performance

**Description**: Use explicit JOIN syntax (INNER JOIN, LEFT JOIN) instead of implicit joins in WHERE clause.

**Why it's bad**:
- Unclear join conditions
- Easy to create accidental cross joins
- Difficult to maintain
- Poor readability
- Mixing join and filter conditions

**Example**:
```sql
-- ❌ BAD (implicit join)
SELECT o.OrderID, c.CustomerName, p.ProductName
FROM Orders o, Customers c, Products p, OrderItems oi
WHERE o.CustomerID = c.CustomerID
  AND oi.OrderID = o.OrderID
  AND oi.ProductID = p.ProductID
  AND o.OrderDate > '2024-01-01';

-- ✅ GOOD (explicit join)
SELECT o.OrderID, c.CustomerName, p.ProductName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
INNER JOIN OrderItems oi ON oi.OrderID = o.OrderID
INNER JOIN Products p ON oi.ProductID = p.ProductID
WHERE o.OrderDate > '2024-01-01';
```

---

### Rule 19: Avoid SELECT * (Wildcard Selection)
**Severity**: High | **Category**: Query Performance

**Description**: Always specify explicit column names instead of using SELECT *.

**Why it's bad**:
- Retrieves unnecessary data (network overhead)
- Breaks when schema changes
- Prevents covering indexes
- Wastes memory and CPU
- Unclear intent
- Security risk (exposes all columns)

**Example**:
```sql
-- ❌ BAD
SELECT * FROM Customers WHERE City = 'New York';

-- ✅ GOOD
SELECT CustomerID, FirstName, LastName, Email
FROM Customers 
WHERE City = 'New York';
```

**Impact**:
- 10-50% performance improvement
- Reduced network traffic
- Better query plan optimization
- Clearer code intent

**Exceptions**:
- Ad-hoc queries in development
- EXISTS checks: `SELECT 1` or `SELECT *` (no difference)
- Temporary debugging

---

### Rule 20: Always Include WHERE Clause in SELECT
**Severity**: Medium | **Category**: Query Performance

**Description**: SELECT statements should have WHERE clauses unless you truly need all rows.

**Why it's bad**:
- Returns entire table (potentially millions of rows)
- High memory consumption
- Network saturation
- Application crashes
- Poor user experience

**Example**:
```sql
-- ❌ BAD (returns all customers)
SELECT CustomerID, FirstName, LastName FROM Customers;

-- ✅ GOOD
SELECT CustomerID, FirstName, LastName 
FROM Customers 
WHERE IsActive = 1 
  AND CreatedDate >= DATEADD(YEAR, -1, GETDATE());

-- ✅ ACCEPTABLE (with TOP/LIMIT)
SELECT TOP 100 CustomerID, FirstName, LastName 
FROM Customers 
ORDER BY CreatedDate DESC;
```

**Exceptions**:
- Small lookup tables (< 100 rows)
- Aggregate queries (COUNT, SUM)
- Data export operations (with proper pagination)

---

### Rule 21: Avoid NOT, <>, != in WHERE Clauses
**Severity**: Medium | **Category**: Query Performance

**Description**: Negative conditions prevent index usage and cause table scans.

**Why it's bad**:
- Cannot use indexes efficiently
- Forces table scans
- Slower query performance
- Higher CPU usage

**Example**:
```sql
-- ❌ BAD
SELECT * FROM Orders WHERE Status <> 'Cancelled';
SELECT * FROM Products WHERE CategoryID != 5;
SELECT * FROM Customers WHERE NOT IsActive = 0;

-- ✅ GOOD (use positive conditions)
SELECT * FROM Orders WHERE Status IN ('Pending', 'Shipped', 'Delivered');
SELECT * FROM Products WHERE CategoryID IN (1, 2, 3, 4, 6, 7, 8);
SELECT * FROM Customers WHERE IsActive = 1;

-- ✅ ALTERNATIVE (filtered index for negative condition)
CREATE INDEX IX_Orders_NotCancelled 
ON Orders(OrderID) 
WHERE Status <> 'Cancelled';
```

**When negative conditions are acceptable**:
- Small tables
- With filtered indexes
- When positive set is too large to enumerate

---

### Rule 22: Avoid ORDER BY in SELECT INTO
**Severity**: Low | **Category**: Query Performance

**Description**: ORDER BY in SELECT INTO is unnecessary and wastes resources.

**Why it's bad**:
- ORDER BY is ignored in SELECT INTO (no guaranteed order)
- Wasted sorting operation
- Increased tempdb usage
- Longer execution time

**Example**:
```sql
-- ❌ BAD
SELECT CustomerID, FirstName, LastName
INTO #TempCustomers
FROM Customers
ORDER BY LastName;  -- Ignored!

-- ✅ GOOD
SELECT CustomerID, FirstName, LastName
INTO #TempCustomers
FROM Customers;

-- Order when you actually need it
SELECT * FROM #TempCustomers ORDER BY LastName;
```

---

### Rule 23: Always Use ORDER BY with TOP/LIMIT
**Severity**: High | **Category**: Query Performance

**Description**: TOP/LIMIT without ORDER BY returns non-deterministic results.

**Why it's bad**:
- Unpredictable results
- Different results on each execution
- Difficult to debug
- Inconsistent application behavior

**Example**:
```sql
-- ❌ BAD (which top 10?)
SELECT TOP 10 CustomerID, FirstName, LastName
FROM Customers;

-- ✅ GOOD (deterministic)
SELECT TOP 10 CustomerID, FirstName, LastName
FROM Customers
ORDER BY CreatedDate DESC;

-- ✅ EVEN BETTER (with tie-breaker)
SELECT TOP 10 CustomerID, FirstName, LastName
FROM Customers
ORDER BY CreatedDate DESC, CustomerID DESC;
```

---

### Rule 24: Avoid SELECT for Variable Assignment
**Severity**: Low | **Category**: Code Quality

**Description**: Use SET for single variable assignment, not SELECT.

**Why it's bad**:
- SELECT can assign from multiple rows (last value wins)
- Unpredictable behavior
- Difficult to debug
- Not clear intent

**Example**:
```sql
-- ❌ BAD
DECLARE @CustomerName VARCHAR(100);
SELECT @CustomerName = CustomerName 
FROM Customers 
WHERE CustomerID = 123;

-- ✅ GOOD (single variable)
DECLARE @CustomerName VARCHAR(100);
SET @CustomerName = (
    SELECT CustomerName 
    FROM Customers 
    WHERE CustomerID = 123
);

-- ✅ ACCEPTABLE (multiple variables from same row)
DECLARE @CustomerName VARCHAR(100), @Email VARCHAR(100);
SELECT @CustomerName = CustomerName, @Email = Email
FROM Customers 
WHERE CustomerID = 123;
```

---

### Rule 25: Always Include WHERE in UPDATE/DELETE
**Severity**: Critical | **Category**: Data Safety

**Description**: UPDATE and DELETE statements must have WHERE clauses unless you truly want to affect all rows.

**Why it's bad**:
- Accidental data modification/loss
- Catastrophic data corruption
- Difficult to recover
- Business impact

**Example**:
```sql
-- ❌ DANGEROUS
UPDATE Customers SET IsActive = 0;  -- Deactivates ALL customers!
DELETE FROM Orders;  -- Deletes ALL orders!

-- ✅ GOOD
UPDATE Customers 
SET IsActive = 0 
WHERE LastLoginDate < DATEADD(YEAR, -2, GETDATE());

DELETE FROM Orders 
WHERE Status = 'Cancelled' 
  AND CreatedDate < DATEADD(YEAR, -7, GETDATE());
```

**Safety measures**:
- Always test with SELECT first
- Use transactions
- Implement soft deletes
- Require code review for DELETE statements

---

### Rule 26: Avoid sp_ Prefix for Stored Procedures
**Severity**: Medium | **Category**: Naming | **Impact**: Performance

**Description**: Don't use sp_ prefix for user stored procedures.

**Why it's bad**:
- SQL Server checks master database first
- Performance overhead on every call
- Conflicts with system procedures
- Confusing naming convention

**Example**:
```sql
-- ❌ BAD
CREATE PROCEDURE sp_GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT * FROM Orders WHERE CustomerID = @CustomerID;
END;

-- ✅ GOOD
CREATE PROCEDURE usp_GetCustomerOrders  -- usp = user stored procedure
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders 
    WHERE CustomerID = @CustomerID;
END;

-- ✅ ALTERNATIVE (schema prefix)
CREATE PROCEDURE dbo.GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders 
    WHERE CustomerID = @CustomerID;
END;
```

**Recommended prefixes**:
- `usp_` - User Stored Procedure
- `fn_` - User Function (but see Rule 27)
- Schema name (e.g., `dbo.`, `app.`)

---

### Rule 27: Avoid fn_ Prefix for Functions
**Severity**: Low | **Category**: Naming

**Description**: Don't use fn_ prefix for user functions.

**Why it's bad**:
- Similar to sp_ issue (system function confusion)
- Unclear function type (scalar vs table-valued)
- Better to use descriptive names

**Example**:
```sql
-- ❌ BAD
CREATE FUNCTION fn_CalculateDiscount(@Price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @Price * 0.1;
END;

-- ✅ GOOD
CREATE FUNCTION CalculateDiscount(@Price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @Price * 0.1;
END;

-- ✅ BETTER (descriptive prefix)
CREATE FUNCTION ufn_CalculateDiscount(@Price DECIMAL(10,2))  -- ufn = user function
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @Price * 0.1;
END;
```

---

### Rule 28: Avoid Functions on Columns in Predicates
**Severity**: Critical | **Category**: Query Performance | **Impact**: Index Usage

**Description**: Never apply functions to columns in WHERE, JOIN, or ON clauses.

**Why it's bad**:
- Prevents index usage (index scan instead of seek)
- Forces full table scan
- 10-100x slower queries
- High CPU usage
- Cannot use statistics

**Example**:
```sql
-- ❌ BAD (prevents index usage)
SELECT * FROM Orders 
WHERE YEAR(OrderDate) = 2024;

SELECT * FROM Customers 
WHERE UPPER(LastName) = 'SMITH';

SELECT * FROM Products 
WHERE SUBSTRING(SKU, 1, 3) = 'ABC';

-- ✅ GOOD (index-friendly)
SELECT * FROM Orders 
WHERE OrderDate >= '2024-01-01' 
  AND OrderDate < '2025-01-01';

SELECT * FROM Customers 
WHERE LastName = 'Smith';  -- Use case-insensitive collation

SELECT * FROM Products 
WHERE SKU LIKE 'ABC%';  -- Or add computed column

-- ✅ ALTERNATIVE (computed column + index)
ALTER TABLE Products 
ADD SKU_Prefix AS SUBSTRING(SKU, 1, 3) PERSISTED;

CREATE INDEX IX_Products_SKU_Prefix ON Products(SKU_Prefix);

SELECT * FROM Products WHERE SKU_Prefix = 'ABC';
```

**Common violations**:
- `YEAR(date_column) = 2024`
- `UPPER(string_column) = 'VALUE'`
- `SUBSTRING(column, 1, 3) = 'ABC'`
- `CONVERT(VARCHAR, column) = 'value'`
- `ISNULL(column, 0) = 0`

**Solutions**:
- Rewrite to apply function to parameter
- Use computed columns
- Use appropriate collations
- Use LIKE with trailing wildcard

---

### Rule 29: Avoid Functions on Columns in JOIN Conditions
**Severity**: Critical | **Category**: Query Performance

**Description**: Never apply functions to columns in JOIN conditions.

**Why it's bad**:
- Same as Rule 28 - prevents index usage
- Nested loop joins instead of hash/merge joins
- Exponentially slower with large tables
- High memory consumption

**Example**:
```sql
-- ❌ BAD
SELECT o.OrderID, c.CustomerName
FROM Orders o
INNER JOIN Customers c ON UPPER(o.CustomerEmail) = UPPER(c.Email);

-- ✅ GOOD
SELECT o.OrderID, c.CustomerName
FROM Orders o
INNER JOIN Customers c ON o.CustomerEmail = c.Email COLLATE SQL_Latin1_General_CP1_CI_AS;

-- ✅ ALTERNATIVE (computed columns)
ALTER TABLE Orders ADD CustomerEmail_Upper AS UPPER(CustomerEmail) PERSISTED;
ALTER TABLE Customers ADD Email_Upper AS UPPER(Email) PERSISTED;
CREATE INDEX IX_Orders_Email_Upper ON Orders(CustomerEmail_Upper);
CREATE INDEX IX_Customers_Email_Upper ON Customers(Email_Upper);

SELECT o.OrderID, c.CustomerName
FROM Orders o
INNER JOIN Customers c ON o.CustomerEmail_Upper = c.Email_Upper;
```

---

### Rule 30: Avoid Scalar UDFs in SELECT Lists
**Severity**: High | **Category**: Query Performance

**Description**: Scalar User-Defined Functions in SELECT lists cause row-by-row execution.

**Why it's bad**:
- Executes once per row (RBAR - Row By Agonizing Row)
- Cannot be parallelized
- Prevents set-based optimization
- 10-1000x slower than inline code

**Example**:
```sql
-- ❌ BAD
CREATE FUNCTION dbo.GetCustomerDiscount(@CustomerID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Discount DECIMAL(5,2);
    SELECT @Discount = DiscountRate 
    FROM CustomerDiscounts 
    WHERE CustomerID = @CustomerID;
    RETURN ISNULL(@Discount, 0);
END;

SELECT 
    OrderID,
    TotalAmount,
    dbo.GetCustomerDiscount(CustomerID) AS Discount  -- Called for EVERY row!
FROM Orders;

-- ✅ GOOD (inline with JOIN)
SELECT 
    o.OrderID,
    o.TotalAmount,
    ISNULL(cd.DiscountRate, 0) AS Discount
FROM Orders o
LEFT JOIN CustomerDiscounts cd ON o.CustomerID = cd.CustomerID;

-- ✅ ALTERNATIVE (inline table-valued function)
CREATE FUNCTION dbo.GetCustomerDiscounts()
RETURNS TABLE
AS
RETURN (
    SELECT CustomerID, DiscountRate
    FROM CustomerDiscounts
);

SELECT 
    o.OrderID,
    o.TotalAmount,
    ISNULL(cd.DiscountRate, 0) AS Discount
FROM Orders o
LEFT JOIN dbo.GetCustomerDiscounts() cd ON o.CustomerID = cd.CustomerID;
```

---

### Rule 31: Avoid Leading Wildcards in LIKE
**Severity**: High | **Category**: Query Performance

**Description**: LIKE patterns starting with % prevent index usage.

**Why it's bad**:
- Cannot use indexes
- Full table scan required
- Slow on large tables

**Example**:
```sql
-- ❌ BAD
SELECT * FROM Customers WHERE LastName LIKE '%son';  -- Ends with 'son'
SELECT * FROM Products WHERE SKU LIKE '%ABC%';       -- Contains 'ABC'

-- ✅ GOOD
SELECT * FROM Customers WHERE LastName LIKE 'John%';  -- Starts with 'John'

-- ✅ ALTERNATIVE (full-text search for contains)
CREATE FULLTEXT INDEX ON Products(SKU);
SELECT * FROM Products WHERE CONTAINS(SKU, 'ABC');

-- ✅ ALTERNATIVE (reverse index for ends-with)
ALTER TABLE Customers ADD LastName_Reversed AS REVERSE(LastName) PERSISTED;
CREATE INDEX IX_Customers_LastName_Reversed ON Customers(LastName_Reversed);
SELECT * FROM Customers WHERE LastName_Reversed LIKE REVERSE('son') + '%';
```

---

### Rule 32: Avoid SELECT in WHILE Loops
**Severity**: Critical | **Category**: Query Performance

**Description**: Never use SELECT statements inside WHILE loops (RBAR pattern).

**Why it's bad**:
- Row-by-row processing
- 100-1000x slower than set-based
- High CPU and I/O
- Locks and blocking

**Example**:
```sql
-- ❌ BAD (RBAR)
DECLARE @CustomerID INT;
DECLARE @Total DECIMAL(10,2);

DECLARE cur CURSOR FOR SELECT CustomerID FROM Customers;
OPEN cur;
FETCH NEXT FROM cur INTO @CustomerID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Total = SUM(Amount) 
    FROM Orders 
    WHERE CustomerID = @CustomerID;
    
    UPDATE Customers 
    SET TotalOrders = @Total 
    WHERE CustomerID = @CustomerID;
    
    FETCH NEXT FROM cur INTO @CustomerID;
END;

CLOSE cur;
DEALLOCATE cur;

-- ✅ GOOD (set-based)
UPDATE c
SET TotalOrders = ISNULL(o.TotalAmount, 0)
FROM Customers c
LEFT JOIN (
    SELECT CustomerID, SUM(Amount) AS TotalAmount
    FROM Orders
    GROUP BY CustomerID
) o ON c.CustomerID = o.CustomerID;
```

---

### Rule 33: Always Specify Columns in INSERT
**Severity**: Medium | **Category**: Code Quality

**Description**: Always specify column names in INSERT statements.

**Why it's bad**:
- Breaks when columns are added/reordered
- Unclear intent
- Difficult to maintain
- Potential data corruption

**Example**:
```sql
-- ❌ BAD
INSERT INTO Customers 
VALUES ('John', 'Doe', 'john@example.com', '555-1234');

-- ✅ GOOD
INSERT INTO Customers (FirstName, LastName, Email, Phone)
VALUES ('John', 'Doe', 'john@example.com', '555-1234');
```

---

## Code Quality Anti-Patterns

### Rule 34: Remove Unused Parameters
**Severity**: Low | **Category**: Code Quality

**Description**: Remove unused input parameters from stored procedures and functions.

**Why it's bad**:
- Confusing interface
- Maintenance overhead
- Misleading documentation
- Potential bugs

**Example**:
```sql
-- ❌ BAD
CREATE PROCEDURE usp_GetOrders
    @CustomerID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Status VARCHAR(20)  -- Never used!
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @CustomerID
      AND OrderDate BETWEEN @StartDate AND @EndDate;
END;

-- ✅ GOOD
CREATE PROCEDURE usp_GetOrders
    @CustomerID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @CustomerID
      AND OrderDate BETWEEN @StartDate AND @EndDate;
END;
```

---

### Rule 35: Remove Unused Variables
**Severity**: Low | **Category**: Code Quality

**Description**: Remove unused local variables.

**Why it's bad**:
- Memory waste
- Confusing code
- Maintenance overhead

**Example**:
```sql
-- ❌ BAD
CREATE PROCEDURE usp_ProcessOrder
    @OrderID INT
AS
BEGIN
    DECLARE @CustomerID INT;
    DECLARE @OrderDate DATE;
    DECLARE @Status VARCHAR(20);  -- Never used!
    
    SELECT @CustomerID = CustomerID, @OrderDate = OrderDate
    FROM Orders
    WHERE OrderID = @OrderID;
    
    -- Process order...
END;

-- ✅ GOOD
CREATE PROCEDURE usp_ProcessOrder
    @OrderID INT
AS
BEGIN
    DECLARE @CustomerID INT;
    DECLARE @OrderDate DATE;
    
    SELECT @CustomerID = CustomerID, @OrderDate = OrderDate
    FROM Orders
    WHERE OrderID = @OrderID;
    
    -- Process order...
END;
```

---

### Rule 36: Avoid Query Hints Unless Necessary
**Severity**: Medium | **Category**: Query Performance

**Description**: Query hints (NOLOCK, FORCESEEK, etc.) should be used sparingly.

**Why it's bad**:
- Overrides query optimizer
- Can cause worse performance
- Difficult to maintain
- May become obsolete with SQL Server updates

**Example**:
```sql
-- ❌ BAD (unnecessary hint)
SELECT * FROM Orders WITH (NOLOCK)  -- Dirty reads!
WHERE OrderDate > '2024-01-01';

-- ✅ GOOD (let optimizer decide)
SELECT OrderID, OrderDate, TotalAmount
FROM Orders
WHERE OrderDate > '2024-01-01';

-- ✅ ACCEPTABLE (when truly needed)
SELECT * FROM Orders WITH (NOLOCK)  -- Reporting query, dirty reads OK
WHERE OrderDate > '2024-01-01';
```

**When hints are acceptable**:
- READ UNCOMMITTED for reporting (with understanding of dirty reads)
- MAXDOP for specific workloads
- RECOMPILE for parameter sniffing issues
- After thorough testing and analysis

---

### Rule 37: Implement Pagination for Large Result Sets
**Severity**: High | **Category**: Query Performance

**Description**: Queries returning more than 200-1000 records should implement pagination.

**Why it's bad**:
- High memory consumption
- Network saturation
- Application crashes
- Poor user experience
- Timeout errors

**Example**:
```sql
-- ❌ BAD (returns all records)
SELECT OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
ORDER BY OrderDate DESC;

-- ✅ GOOD (pagination with OFFSET/FETCH)
DECLARE @PageNumber INT = 1;
DECLARE @PageSize INT = 50;

SELECT OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
ORDER BY OrderDate DESC
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;

-- ✅ ALTERNATIVE (keyset pagination - better performance)
DECLARE @LastOrderDate DATETIME = '2024-01-01';
DECLARE @LastOrderID INT = 0;
DECLARE @PageSize INT = 50;

SELECT TOP (@PageSize) OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
WHERE OrderDate < @LastOrderDate 
   OR (OrderDate = @LastOrderDate AND OrderID < @LastOrderID)
ORDER BY OrderDate DESC, OrderID DESC;
```

**Pagination strategies**:
- OFFSET/FETCH: Simple but slower for large offsets
- Keyset pagination: Faster, consistent performance
- Cursor-based: For real-time data

---

## Security Anti-Patterns

### Rule 38: Avoid Dynamic SQL with String Concatenation
**Severity**: Critical | **Category**: Security | **Impact**: SQL Injection

**Description**: Never build dynamic SQL using string concatenation with user input.

**Why it's bad**:
- SQL injection vulnerability
- Data breach risk
- Data corruption
- Unauthorized access

**Example**:
```sql
-- ❌ DANGEROUS (SQL Injection)
CREATE PROCEDURE usp_GetCustomerByName
    @CustomerName VARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = 'SELECT * FROM Customers WHERE CustomerName = ''' + @CustomerName + '''';
    EXEC(@SQL);
END;
-- Attack: @CustomerName = "'; DROP TABLE Customers; --"

-- ✅ GOOD (parameterized)
CREATE PROCEDURE usp_GetCustomerByName
    @CustomerName VARCHAR(100)
AS
BEGIN
    SELECT CustomerID, FirstName, LastName, Email
    FROM Customers 
    WHERE CustomerName = @CustomerName;
END;

-- ✅ ACCEPTABLE (dynamic SQL with sp_executesql)
CREATE PROCEDURE usp_GetCustomerByName
    @CustomerName VARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Params NVARCHAR(MAX);
    
    SET @SQL = N'SELECT CustomerID, FirstName, LastName, Email
                 FROM Customers 
                 WHERE CustomerName = @CustomerName';
    SET @Params = N'@CustomerName VARCHAR(100)';
    
    EXEC sp_executesql @SQL, @Params, @CustomerName = @CustomerName;
END;
```

**Safe dynamic SQL practices**:
- Use sp_executesql with parameters
- Validate and sanitize input
- Use QUOTENAME() for identifiers
- Whitelist allowed values
- Principle of least privilege

---

### Rule 39: Avoid Hardcoded Credentials
**Severity**: Critical | **Category**: Security

**Description**: Never hardcode passwords or connection strings in SQL code.

**Why it's bad**:
- Security breach
- Credentials in source control
- Difficult to rotate credentials
- Compliance violations

**Example**:
```sql
-- ❌ DANGEROUS
SELECT * FROM OPENROWSET(
    'SQLNCLI',
    'Server=myserver;Database=mydb;UID=admin;PWD=Password123!',
    'SELECT * FROM RemoteTable'
);

-- ✅ GOOD (use linked servers)
-- Setup once by DBA with secure credentials
EXEC sp_addlinkedserver @server='RemoteServer';
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname='RemoteServer',
    @useself='FALSE',
    @rmtuser='admin',
    @rmtpassword='SecurePassword';

-- Use in queries
SELECT * FROM RemoteServer.mydb.dbo.RemoteTable;

-- ✅ ALTERNATIVE (use Windows Authentication)
SELECT * FROM OPENROWSET(
    'SQLNCLI',
    'Server=myserver;Database=mydb;Trusted_Connection=yes',
    'SELECT * FROM RemoteTable'
);
```

---

## Maintainability Anti-Patterns

### Rule 40: Avoid ORDER BY in Views
**Severity**: Medium | **Category**: Maintainability

**Description**: Views should not contain ORDER BY clauses (except with TOP/OFFSET).

**Why it's bad**:
- ORDER BY in views is ignored
- Misleading to developers
- Wasted resources
- Not guaranteed order

**Example**:
```sql
-- ❌ BAD (ORDER BY ignored)
CREATE VIEW vw_RecentOrders
AS
SELECT OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
WHERE OrderDate >= DATEADD(MONTH, -1, GETDATE())
ORDER BY OrderDate DESC;  -- Ignored!

-- ✅ GOOD (no ORDER BY in view)
CREATE VIEW vw_RecentOrders
AS
SELECT OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
WHERE OrderDate >= DATEADD(MONTH, -1, GETDATE());

-- Order when querying the view
SELECT * FROM vw_RecentOrders ORDER BY OrderDate DESC;

-- ✅ ACCEPTABLE (with TOP)
CREATE VIEW vw_Top10RecentOrders
AS
SELECT TOP 10 OrderID, OrderDate, CustomerName, TotalAmount
FROM Orders
WHERE OrderDate >= DATEADD(MONTH, -1, GETDATE())
ORDER BY OrderDate DESC;  -- Required for TOP
```

---

### Rule 41: Avoid CURSOR - Use Set-Based Operations
**Severity**: Critical | **Category**: Query Performance | **Impact**: RBAR

**Description**: Cursors cause Row-By-Agonizing-Row (RBAR) processing. Use set-based operations instead.

**Why it's bad**:
- 100-1000x slower than set-based
- High CPU and memory usage
- Locks and blocking
- Not scalable
- Difficult to maintain

**Example**:
```sql
-- ❌ BAD (CURSOR - RBAR)
DECLARE @OrderID INT;
DECLARE @Total DECIMAL(10,2);

DECLARE order_cursor CURSOR FOR
    SELECT OrderID FROM Orders WHERE Status = 'Pending';

OPEN order_cursor;
FETCH NEXT FROM order_cursor INTO @OrderID;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Calculate total
    SELECT @Total = SUM(Quantity * UnitPrice)
    FROM OrderItems
    WHERE OrderID = @OrderID;
    
    -- Update order
    UPDATE Orders
    SET TotalAmount = @Total
    WHERE OrderID = @OrderID;
    
    FETCH NEXT FROM order_cursor INTO @OrderID;
END;

CLOSE order_cursor;
DEALLOCATE order_cursor;

-- ✅ GOOD (set-based)
UPDATE o
SET TotalAmount = oi.Total
FROM Orders o
INNER JOIN (
    SELECT OrderID, SUM(Quantity * UnitPrice) AS Total
    FROM OrderItems
    GROUP BY OrderID
) oi ON o.OrderID = oi.OrderID
WHERE o.Status = 'Pending';
```

**When cursors are acceptable** (rare):
- Administrative tasks (one-time scripts)
- Complex business logic that cannot be set-based
- Processing external data row-by-row
- Always document why cursor is necessary

---

### Rule 42: Use Meaningful Names
**Severity**: Low | **Category**: Code Quality

**Description**: Use descriptive, meaningful names for all database objects.

**Why it's bad**:
- Difficult to understand
- Maintenance overhead
- Onboarding challenges
- Increased bugs

**Example**:
```sql
-- ❌ BAD
CREATE TABLE t1 (
    id INT,
    n VARCHAR(50),
    d DATE,
    a DECIMAL(10,2)
);

CREATE PROCEDURE sp1 (@p1 INT) AS
BEGIN
    SELECT * FROM t1 WHERE id = @p1;
END;

-- ✅ GOOD
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerName VARCHAR(50) NOT NULL,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10,2) NOT NULL
);

CREATE PROCEDURE usp_GetOrderByID 
    @OrderID INT
AS
BEGIN
    SELECT OrderID, CustomerName, OrderDate, TotalAmount
    FROM Orders 
    WHERE OrderID = @OrderID;
END;
```

**Naming conventions**:
- Tables: Plural nouns (Customers, Orders)
- Columns: Descriptive names (FirstName, OrderDate)
- Primary Keys: TableName + ID (CustomerID)
- Foreign Keys: ReferencedTable + ID (CustomerID)
- Indexes: IX_TableName_ColumnName
- Stored Procedures: usp_VerbNoun (usp_GetCustomer)
- Functions: ufn_VerbNoun (ufn_CalculateDiscount)

---

### Rule 43: Document Complex Logic
**Severity**: Low | **Category**: Maintainability

**Description**: Add comments to explain complex business logic, not obvious code.

**Why it's bad**:
- Difficult to maintain
- Knowledge loss
- Increased bugs
- Longer onboarding

**Example**:
```sql
-- ❌ BAD (no comments for complex logic)
CREATE PROCEDURE usp_CalculateCommission
    @SalesPersonID INT,
    @Month DATE
AS
BEGIN
    UPDATE SalesPeople
    SET Commission = (
        SELECT SUM(Amount) * 
               CASE 
                   WHEN SUM(Amount) > 100000 THEN 0.15
                   WHEN SUM(Amount) > 50000 THEN 0.10
                   ELSE 0.05
               END
        FROM Sales
        WHERE SalesPersonID = @SalesPersonID
          AND MONTH(SaleDate) = MONTH(@Month)
    )
    WHERE SalesPersonID = @SalesPersonID;
END;

-- ✅ GOOD (documented)
CREATE PROCEDURE usp_CalculateCommission
    @SalesPersonID INT,
    @Month DATE
AS
BEGIN
    /*
    Commission Calculation Rules:
    - 15% for sales > $100,000
    - 10% for sales > $50,000
    - 5% for sales ≤ $50,000
    
    Business Rule: Commission is calculated monthly
    Last Updated: 2024-01-15 by John Doe
    */
    
    UPDATE SalesPeople
    SET Commission = (
        SELECT SUM(Amount) * 
               CASE 
                   WHEN SUM(Amount) > 100000 THEN 0.15  -- Top tier
                   WHEN SUM(Amount) > 50000 THEN 0.10   -- Mid tier
                   ELSE 0.05                             -- Base tier
               END
        FROM Sales
        WHERE SalesPersonID = @SalesPersonID
          AND MONTH(SaleDate) = MONTH(@Month)
    )
    WHERE SalesPersonID = @SalesPersonID;
END;
```

---

## Summary Table

| Rule | Severity | Category | Impact |
|------|----------|----------|--------|
| 1. Avoid sql_variant | Medium | Data Type | Type Safety |
| 2. Minimize NVARCHAR | Medium | Data Type | Storage |
| 3. Avoid Single BIT | Low | Data Type | Storage |
| 4. VARCHAR(MAX) for Large Data | Medium | Data Type | Performance |
| 5. Use CHAR for Small Data | Low | Data Type | Performance |
| 6. Every Table Needs PK | Critical | Schema | Data Integrity |
| 7. Single-Column PK | Medium | Schema | Complexity |
| 8. Appropriate PK Type | Medium | Schema | Performance |
| 9. Use XML Type | Medium | Data Type | Functionality |
| 10. Minimize NULL | Medium | Schema | Query Logic |
| 11. FK Must Be NOT NULL | High | Schema | Data Integrity |
| 12. Indexed Columns NOT NULL | Medium | Schema | Performance |
| 13. Avoid Triggers | High | Schema | Maintainability |
| 14. Avoid Reserved Words | Medium | Naming | Syntax |
| 15. Tables Need Indexes | Critical | Performance | Query Speed |
| 16. Index WHERE Columns | High | Performance | Query Speed |
| 17. Remove Unused Tables | Low | Maintainability | Storage |
| 18. Explicit JOIN Syntax | High | Performance | Readability |
| 19. Avoid SELECT * | High | Performance | Network |
| 20. Include WHERE Clause | Medium | Performance | Data Volume |
| 21. Avoid NOT/!= | Medium | Performance | Index Usage |
| 22. No ORDER BY in SELECT INTO | Low | Performance | Resources |
| 23. ORDER BY with TOP | High | Performance | Determinism |
| 24. SET for Variables | Low | Code Quality | Clarity |
| 25. WHERE in UPDATE/DELETE | Critical | Data Safety | Data Loss |
| 26. Avoid sp_ Prefix | Medium | Naming | Performance |
| 27. Avoid fn_ Prefix | Low | Naming | Clarity |
| 28. No Functions on Columns | Critical | Performance | Index Usage |
| 29. No Functions in JOIN | Critical | Performance | Index Usage |
| 30. Avoid Scalar UDF | High | Performance | RBAR |
| 31. No Leading Wildcards | High | Performance | Index Usage |
| 32. No SELECT in WHILE | Critical | Performance | RBAR |
| 33. Specify INSERT Columns | Medium | Code Quality | Maintainability |
| 34. Remove Unused Parameters | Low | Code Quality | Clarity |
| 35. Remove Unused Variables | Low | Code Quality | Clarity |
| 36. Avoid Query Hints | Medium | Performance | Optimizer |
| 37. Implement Pagination | High | Performance | Scalability |
| 38. No Dynamic SQL Concat | Critical | Security | SQL Injection |
| 39. No Hardcoded Credentials | Critical | Security | Data Breach |
| 40. No ORDER BY in Views | Medium | Maintainability | Clarity |
| 41. Avoid CURSOR | Critical | Performance | RBAR |
| 42. Meaningful Names | Low | Code Quality | Readability |
| 43. Document Complex Logic | Low | Maintainability | Knowledge |

---

## Quick Reference: Performance Impact

### Critical (Fix Immediately)
- Rule 6: Every Table Needs PK
- Rule 15: Tables Need Indexes
- Rule 25: WHERE in UPDATE/DELETE
- Rule 28: No Functions on Columns
- Rule 29: No Functions in JOIN
- Rule 32: No SELECT in WHILE
- Rule 38: No Dynamic SQL Concat
- Rule 39: No Hardcoded Credentials
- Rule 41: Avoid CURSOR

### High (Fix Soon)
- Rule 11: FK Must Be NOT NULL
- Rule 13: Avoid Triggers
- Rule 16: Index WHERE Columns
- Rule 18: Explicit JOIN Syntax
- Rule 19: Avoid SELECT *
- Rule 23: ORDER BY with TOP
- Rule 30: Avoid Scalar UDF
- Rule 31: No Leading Wildcards
- Rule 37: Implement Pagination

### Medium (Plan to Fix)
- Rules 1-5: Data Type Issues
- Rules 7-8, 10, 12, 14: Schema Design
- Rules 20-22, 24, 26, 33, 36, 40: Code Quality

### Low (Technical Debt)
- Rules 3, 5, 17, 27, 34-35, 42-43: Code Quality & Maintainability

---

## Additional Resources

- [SQL Server Best Practices](https://docs.microsoft.com/sql/relational-databases/best-practices)
- [Query Performance Tuning](https://docs.microsoft.com/sql/relational-databases/performance/query-performance-tuning)
- [Index Design Guidelines](https://docs.microsoft.com/sql/relational-databases/sql-server-index-design-guide)
- [Security Best Practices](https://docs.microsoft.com/sql/relational-databases/security/security-best-practices)

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: Database Team
