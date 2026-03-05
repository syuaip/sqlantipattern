-- 1. DYNAMIC SQL (Security risk & lack of query plan reuse)
DECLARE @DynamicSQL NVARCHAR(MAX);
SET @DynamicSQL = 'SELECT * FROM Sales.Orders'; -- 2. SELECT * (Excessive IO/Memory)

-- 3. CURSOR OPERATIONS (Row-by-row processing instead of set-based)
DECLARE OrderCursor CURSOR FOR 
EXEC sp_executesql @DynamicSQL;

OPEN OrderCursor;
DECLARE @OrderID INT, @CustomerID INT;
FETCH NEXT FROM OrderCursor INTO @OrderID, @CustomerID;

-- 4. SELECT WITHIN A WHILE STATEMENT (High overhead)
WHILE @@FETCH_STATUS = 0
BEGIN
    -- 5. SELECT WITHOUT WHERE (Full table scan every loop)
    -- 6. UDF IN WHERE CLAUSE (Forces row-by-row function execution, kills indexing)
    -- 7. NOT IN (Can return zero results if any NULLs exist; poor performance)
    SELECT TotalAmount 
    FROM Sales.OrderDetails 
    WHERE dbo.CalculateTax(TotalAmount) > 100 
    AND ProductID NOT IN (SELECT ProductID FROM Warehouse.DiscontinuedItems);

    -- 8. SELECT WITH <> (Non-SARGable; prevents index usage)
    -- 9. SELECT WITH LIKE % (Leading wildcard prevents index seeks)
    SELECT CustomerName 
    FROM Sales.Customers 
    WHERE RegionCode <> 'US' 
    AND EmailAddress LIKE '%@gmail.com';

    FETCH NEXT FROM OrderCursor INTO @OrderID, @CustomerID;
END

CLOSE OrderCursor;
DEALLOCATE OrderCursor;