CREATE TABLE sales_transactions (
    TransactionID INT,
    CustomerID INT,
    TransactionDate TIMESTAMP,
    ProductID INT,
    ProductCategory VARCHAR(50),
    Quantity INT,
    PricePerUnit NUMERIC(10, 2),
    TotalAmount NUMERIC(10, 2),
    TrustPointsUsed INT,
    PaymentMethod VARCHAR(50),
    DiscountApplied NUMERIC(5, 2)
);
