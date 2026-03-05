-- ===============================================
-- DROP DATABASE IF THEY EXIST (to reset environment)
-- ===============================================
USE tempdb;
GO

DECLARE @SQL nvarchar(max);

IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = 'pto_db') 
BEGIN
    SET @SQL = 
        N'USE pto_db;
          ALTER DATABASE pto_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
          USE master;
          DROP DATABASE pto_db;';
    EXEC (@SQL);
    USE tempdb;
END;
GO

CREATE DATABASE pto_db;
GO

USE pto_db;
GO


-- ===============================================
-- DROP TABLES IF THEY EXIST (to reset environment)
-- ===============================================
IF OBJECT_ID('dbo.ProductReviews', 'U') IS NOT NULL DROP TABLE ProductReviews;
IF OBJECT_ID('dbo.InventoryHistory', 'U') IS NOT NULL DROP TABLE InventoryHistory;
IF OBJECT_ID('dbo.Shipments', 'U') IS NOT NULL DROP TABLE Shipments;
IF OBJECT_ID('dbo.OrderItems', 'U') IS NOT NULL DROP TABLE OrderItems;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE Orders;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE Products;
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL DROP TABLE Categories;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE Customers;

-- ===============================================
-- TABLES
-- ===============================================
CREATE TABLE Customers (
    CustomerID INT IDENTITY PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100) UNIQUE,
    Phone NVARCHAR(20),
    DateJoined DATETIME DEFAULT GETDATE(),
    IsActive BIT DEFAULT 1
);
GO

CREATE TABLE Categories (
    CategoryID INT IDENTITY PRIMARY KEY,
    CategoryName NVARCHAR(100),
    ParentCategoryID INT NULL,
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID)
);
GO

CREATE TABLE Products (
    ProductID INT IDENTITY PRIMARY KEY,
    ProductName NVARCHAR(100),
    Description NVARCHAR(MAX),
    Price DECIMAL(10, 2),
    DiscountRate DECIMAL(5, 2) DEFAULT 0, -- Percentage (e.g., 10.00 for 10%)
    StockQuantity INT,
    CategoryID INT,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);
GO

CREATE TABLE Orders (
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(50),
    TotalAmount DECIMAL(12, 2),
    ShippingAddress NVARCHAR(255),
    BillingAddress NVARCHAR(255),
    PaymentMethod NVARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(10, 2),
    Discount DECIMAL(5, 2) DEFAULT 0,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

CREATE TABLE Shipments (
    ShipmentID INT IDENTITY PRIMARY KEY,
    OrderID INT,
    Carrier NVARCHAR(100),
    TrackingNumber NVARCHAR(100),
    ShippedDate DATETIME,
    EstimatedDeliveryDate DATETIME,
    DeliveredDate DATETIME NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);
GO

CREATE TABLE ProductReviews (
    ReviewID INT IDENTITY PRIMARY KEY,
    ProductID INT,
    CustomerID INT,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    ReviewText NVARCHAR(MAX),
    ReviewDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

CREATE TABLE InventoryHistory (
    InventoryID INT IDENTITY PRIMARY KEY,
    ProductID INT,
    ChangeType NVARCHAR(20), -- Restock, Purchase, Adjustment
    QuantityChanged INT,
    ChangeDate DATETIME DEFAULT GETDATE(),
    Notes NVARCHAR(255),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

-- ===============================================
-- STORED PROCEDURE: DEMO DATA GENERATOR
-- ===============================================
CREATE OR ALTER PROCEDURE sp_GenerateECommerceDemoData
    @CustomerCount INT = 10,
    @ProductCount INT = 15,
    @OrderCount INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @i INT;

    -- Insert Categories
    DELETE FROM Categories;
    INSERT INTO Categories (CategoryName) VALUES
    ('Electronics'), ('Books'), ('Clothing'), ('Home & Kitchen'), ('Sports');

    -- Insert Customers
    SET @i = 1;
    WHILE @i <= @CustomerCount
    BEGIN
        INSERT INTO Customers (FirstName, LastName, Email, Phone, DateJoined, IsActive)
        VALUES (
            CHOOSE((ABS(CHECKSUM(NEWID())) % 6) + 1, 'John', 'Jane', 'Alex', 'Emily', 'Michael', 'Sarah'),
            CHOOSE((ABS(CHECKSUM(NEWID())) % 6) + 1, 'Smith', 'Doe', 'Johnson', 'Brown', 'Williams', 'Miller'),
            CONCAT('user', @i, '_', ABS(CHECKSUM(NEWID())) % 10000, '@example.com'),
            CONCAT('+1-202-', FORMAT(ABS(CHECKSUM(NEWID())) % 900 + 100, '000'), '-', FORMAT(ABS(CHECKSUM(NEWID())) % 9000 + 1000, '0000')),
            DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1000, GETDATE()),
            1
        );
        SET @i += 1;
    END

	-- Insert Products
	SET @i = 1;
	WHILE @i <= @ProductCount
	BEGIN
		DECLARE @DiscountRate DECIMAL(5,2) = ROUND(RAND(CHECKSUM(NEWID())) * 30, 2); -- Random 0 to 30%

		INSERT INTO Products (
			ProductName, Description, Price, DiscountRate, StockQuantity, CategoryID, IsActive, CreatedAt, UpdatedAt
		)
		VALUES (
			CONCAT('Product ', @i, '-', ABS(CHECKSUM(NEWID())) % 1000),
			CONCAT('This is the description for Product ', @i),
			ROUND(RAND(CHECKSUM(NEWID())) * (500 - 10) + 10, 2),
			@DiscountRate,
			ABS(CHECKSUM(NEWID())) % 1000,
			(SELECT TOP 1 CategoryID FROM Categories ORDER BY NEWID()),
			1,
			DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 500, GETDATE()),
			NULL
		);

		SET @i += 1;
	END

    -- Insert Orders, Items, Shipments, Reviews, InventoryHistory
    DECLARE @CustomerID INT, @OrderID INT, @ProductID INT, @Price DECIMAL(10,2), @Qty INT, @Total DECIMAL(12,2);

    SET @i = 1;
    WHILE @i <= @OrderCount
    BEGIN
        SELECT TOP 1 @CustomerID = CustomerID FROM Customers ORDER BY NEWID();

        INSERT INTO Orders (CustomerID, OrderDate, Status, TotalAmount, ShippingAddress, BillingAddress, PaymentMethod)
        VALUES (@CustomerID, DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 300, GETDATE()), 
                CHOOSE((ABS(CHECKSUM(NEWID())) % 3) + 1, 'Pending', 'Shipped', 'Delivered'),
                0, '123 Main St', '123 Main St', 'Credit Card');

        SET @OrderID = SCOPE_IDENTITY();
        SET @Total = 0;

        DECLARE @j INT = 1;
        DECLARE @ItemsInOrder INT = (ABS(CHECKSUM(NEWID())) % 4 + 1);

        WHILE @j <= @ItemsInOrder
        BEGIN
            SELECT TOP 1 @ProductID = ProductID, @Price = Price FROM Products ORDER BY NEWID();
            SET @Qty = ABS(CHECKSUM(NEWID())) % 3 + 1;
            DECLARE @Discount DECIMAL(5,2) = ROUND(RAND() * 0.2, 2);

            INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice, Discount)
            VALUES (@OrderID, @ProductID, @Qty, @Price, @Discount);

            SET @Total += @Qty * @Price * (1 - @Discount);

            -- Inventory History
            INSERT INTO InventoryHistory (ProductID, ChangeType, QuantityChanged, Notes)
            VALUES (@ProductID, 'Purchase', -@Qty, CONCAT('Order #', @OrderID));

            -- Occasionally insert a review
            IF (ABS(CHECKSUM(NEWID())) % 4 = 0)
            BEGIN
                INSERT INTO ProductReviews (ProductID, CustomerID, Rating, ReviewText)
                VALUES (@ProductID, @CustomerID, ABS(CHECKSUM(NEWID())) % 5 + 1, 'Auto-generated review.');
            END

            SET @j += 1;
        END

        UPDATE Orders SET TotalAmount = @Total WHERE OrderID = @OrderID;

        -- Shipment
        INSERT INTO Shipments (OrderID, Carrier, TrackingNumber, ShippedDate, EstimatedDeliveryDate)
        VALUES (
            @OrderID,
            CHOOSE((ABS(CHECKSUM(NEWID())) % 3) + 1, 'UPS', 'FedEx', 'DHL'),
            CONCAT('TRACK-', ABS(CHECKSUM(NEWID()))),
            DATEADD(DAY, 1, GETDATE()),
            DATEADD(DAY, 5, GETDATE())
        );

        SET @i += 1;
    END

    PRINT '? E-Commerce demo data generated successfully!';
END
GO

-- =========================================================
-- ?? VIEWS: One optimized, one inefficient (simulated joins)
-- =========================================================

-- Efficient view: Indexed and narrowed
CREATE OR ALTER VIEW vw_EfficientOrderSummary AS
SELECT 
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    c.FirstName + ' ' + c.LastName AS CustomerName
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID;
GO

-- Inefficient view: Wide columns, joins, no filtering
CREATE OR ALTER VIEW vw_HeavyOrderView AS
SELECT 
    -- Orders
    o.OrderID AS Order_OrderID,
    o.CustomerID AS Order_CustomerID,
    o.OrderDate,
    o.Status,
    o.TotalAmount,
    o.ShippingAddress,
    o.BillingAddress,
    o.PaymentMethod,

    -- OrderItems
    oi.OrderItemID,
    oi.OrderID AS OrderItem_OrderID,
    oi.ProductID AS OrderItem_ProductID,
    oi.Quantity,
    oi.UnitPrice,
    oi.Discount,

    -- Products
    p.ProductID AS Product_ProductID,
    p.ProductName,
    p.Description,
    p.Price,
    p.StockQuantity,
    p.CategoryID,
    p.IsActive AS Product_IsActive,
    p.CreatedAt,
    p.UpdatedAt,

    -- Customers
    c.CustomerID AS Customer_CustomerID,
    c.FirstName,
    c.LastName,
    c.Email,
    c.Phone,
    c.DateJoined,
    c.IsActive AS Customer_IsActive,

    -- Shipments
    s.ShipmentID,
    s.OrderID AS Shipment_OrderID,
    s.Carrier,
    s.TrackingNumber,
    s.ShippedDate,
    s.EstimatedDeliveryDate,
    s.DeliveredDate

FROM Orders o
LEFT JOIN OrderItems oi ON o.OrderID = oi.OrderID
LEFT JOIN Products p ON oi.ProductID = p.ProductID
LEFT JOIN Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN Shipments s ON o.OrderID = s.OrderID;
GO


-- =========================================================
-- ? INDEXES: Missing vs. created for tuning exercises
-- =========================================================

-- Useful index: speeds up date range + customer filter
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_OrderDate
ON Orders(CustomerID, OrderDate);
GO

-- Intentional missing index (for product review search)
-- Simulated problem: WHERE ProductID = ? in high volume
-- CREATE NONCLUSTERED INDEX IX_ProductReviews_ProductID ON ProductReviews(ProductID);

-- =========================================================
-- ?? STORED PROC: Inefficient pattern for demo purposes
-- =========================================================

CREATE OR ALTER PROCEDURE sp_BadOrderQuery
AS
BEGIN
    -- Simulated "slow" query: correlated subquery, SELECT *
    SELECT 
        o.*,
        (SELECT COUNT(*) FROM OrderItems oi WHERE oi.OrderID = o.OrderID) AS ItemCount,
        (SELECT AVG(UnitPrice) FROM OrderItems oi WHERE oi.OrderID = o.OrderID) AS AvgPrice
    FROM Orders o
    WHERE EXISTS (
        SELECT 1 FROM Customers c WHERE c.CustomerID = o.CustomerID AND c.IsActive = 1
    );
END
GO

-- =========================================================
-- ?? TRIGGERS: Inventory stock & audit updates
-- =========================================================

-- Trigger: Decrease stock on order item insert
CREATE OR ALTER TRIGGER trg_DecreaseStockOnPurchase
ON OrderItems
AFTER INSERT
AS
BEGIN
    UPDATE p
    SET StockQuantity = StockQuantity - i.Quantity
    FROM Products p
    JOIN inserted i ON p.ProductID = i.ProductID;

    -- Insert into InventoryHistory
    INSERT INTO InventoryHistory (ProductID, ChangeType, QuantityChanged, ChangeDate, Notes)
    SELECT 
        i.ProductID, 'Trigger-Purchase', -i.Quantity, GETDATE(), CONCAT('OrderItemID: ', i.OrderItemID)
    FROM inserted i;
END
GO

-- Trigger: Log manual stock changes
CREATE OR ALTER TRIGGER trg_LogManualInventoryChange
ON Products
AFTER UPDATE
AS
BEGIN
    IF UPDATE(StockQuantity)
    BEGIN
        INSERT INTO InventoryHistory (ProductID, ChangeType, QuantityChanged, Notes)
        SELECT 
            i.ProductID,
            'Manual-Update',
            i.StockQuantity - d.StockQuantity,
            'Manual stock update'
        FROM inserted i
        JOIN deleted d ON i.ProductID = d.ProductID;
    END
END
GO