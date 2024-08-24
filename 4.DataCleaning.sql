select * from sales_trnsc order by transactionid;

-- verifying if transactionid unique
select transactionid, count(*) as rows_present
from sales_trnsc
group by transactionid
order by transactionid;

--only transactionid = 2 having duplicate value and transactionid = 4 not present hence making one of the value 2 to 4
select * from sales_trnsc where transactionid = 2;

--since there is no relation between transactionid and transactiondate any one of the values could be changed to 4
UPDATE sales_trnsc
SET transactionid = 4
WHERE TransactionID = 2 and customerid is null;

--quantity cannot be negative or zero hence checking key-value distribution of quantity to replace those values with the mode
select quantity, count(*) from sales_trnsc group by quantity order by quantity;

--replacing all negative values with 1 as it is mode covering almost(50%) of the data
UPDATE sales_trnsc
SET quantity = 1
WHERE quantity <= 0;

-- checking the skewness of priceperunit data to determine replacement of null values with mean or median
WITH Stats AS (
    SELECT
        COUNT(*) AS N,
        AVG(priceperunit) AS Mean,
        STDDEV(priceperunit) AS StdDev -- Use STDDEV or another appropriate function
    FROM
        sales_trnsc
),

Moments AS (
    SELECT
        (priceperunit - s.Mean) AS Deviation,
        POWER(priceperunit - s.Mean, 3) AS CubedDeviation,
		s.N,
		s.StdDev
    FROM
        sales_trnsc
    CROSS JOIN
        Stats s
),

Skewness AS (
    SELECT
        n, Stddev, (SUM(m.CubedDeviation) / m.N) / POWER(m.StdDev, 3) * (m.N / ((m.N - 1) * (m.N - 2))) AS Skewness
    FROM
        Moments m
	   GROUP BY n, Stddev
)

select * from Skewness;
--since is skewed and has high std deviation we will use median

--checking for outliers 
WITH Quartiles AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY PricePerUnit) AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY PricePerUnit) AS Q3
    FROM sales_trnsc
    WHERE PricePerUnit IS NOT NULL
),
OutlierLimits AS (
    SELECT 
        Q1 - 1.5 * (Q3 - Q1) AS LowerBound,
        Q3 + 1.5 * (Q3 - Q1) AS UpperBound
    FROM Quartiles
)
SELECT * 
FROM sales_trnsc
WHERE PricePerUnit < (SELECT LowerBound FROM OutlierLimits)
   OR PricePerUnit > (SELECT UpperBound FROM OutlierLimits);

-- 7 outliers present all equal to 500

--getting median price of each product category
WITH OrderedData AS (
    SELECT
		productcategory,
        priceperunit,
        ROW_NUMBER() OVER (PARTITION BY productcategory ORDER BY priceperunit) AS RowAsc,
        ROW_NUMBER() OVER (PARTITION BY productcategory ORDER BY priceperunit DESC) AS RowDesc
    FROM
        sales_trnsc
	WHERE
		priceperunit is not null
),

Median_Data AS (
    SELECT
        productcategory, round(avg(priceperunit)::numeric,2) as avg
    FROM
        OrderedData
    WHERE
        RowAsc = RowDesc
        OR RowAsc + 1 = RowDesc
        OR RowAsc = RowDesc + 1
	GROUP BY
		productcategory
),
	

 cte as (Select *, coalesce(st.priceperunit,md.avg) as price_unit from sales_trnsc st 
	left join Median_Data md ON st.productcategory = md.productcategory)


Update sales_trnsc
set priceperunit = cte.price_unit from cte
where sales_trnsc.transactionid = cte.transactionid

select * from sales_trnsc

--updating totalamount with priceperunit * quantity


Update sales_trnsc
set totalamount = priceperunit * quantity

--since trustpointused cannot be negative 

Update sales_trnsc
set trustpointsused = ABS(trustpointsused)

-- replacing paymentmethod whose value is nan with unknown

Update sales_trnsc
set paymentmethod = 'Unknown'
WHERE PaymentMethod = 'nan'

--checking productcategory wise discount applied stats to replace null values in the columm
select productcategory, count(*) as no_of_dicounts, count(distinct discountapplied) as distict_discounts
from sales_trnsc
group by productcategory;

select productid, count(*) as no_of_dicounts, count(distinct discountapplied) as distict_discounts
from sales_trnsc
group by productid;

--checking skewness and spread of discountapplied as no pattern available
WITH Stats AS (
    SELECT
        COUNT(*) AS N,
        AVG(discountapplied) AS Mean,
        STDDEV(discountapplied) AS StdDev -- Use STDDEV or another appropriate function
    FROM
        sales_trnsc
),

Moments AS (
    SELECT
        (discountapplied - s.Mean) AS Deviation,
        POWER(discountapplied - s.Mean, 3) AS CubedDeviation,
		s.N,
		s.StdDev
    FROM
        sales_trnsc
    CROSS JOIN
        Stats s
),

Skewness AS (
    SELECT
        n, Stddev, (SUM(m.CubedDeviation) / m.N) / POWER(m.StdDev, 3) * (m.N / ((m.N - 1) * (m.N - 2))) AS Skewness
    FROM
        Moments m
	   GROUP BY n, Stddev
)

select * from Skewness;

--using median as data skewed


WITH OrderedData AS (
    SELECT
		productcategory,
        discountapplied,
        ROW_NUMBER() OVER (PARTITION BY productcategory ORDER BY discountapplied) AS RowAsc,
        ROW_NUMBER() OVER (PARTITION BY productcategory ORDER BY discountapplied DESC) AS RowDesc
    FROM
        sales_trnsc
	WHERE
		discountapplied is not null
),

Median_Data AS (
    SELECT
        productcategory, round(avg(discountapplied)::numeric,2) as avg
    FROM
        OrderedData
    WHERE
        RowAsc = RowDesc
        OR RowAsc + 1 = RowDesc
        OR RowAsc = RowDesc + 1
	GROUP BY
		productcategory
),
 cte as (Select *, coalesce(st.discountapplied,md.avg) as discount_apld from sales_trnsc st 
	left join Median_Data md ON st.productcategory = md.productcategory)

-- replacing where discount is null with median 
Update sales_trnsc
set discountapplied = cte.discount_apld from cte
where sales_trnsc.transactionid = cte.transactionid

--filling null values in customerID with 0 so that they create their own group 
--and do not hamper the insights of other customers
Update sales_trnsc 
set customerid = 0
where customerid is null

-- removing columns where transactiondate  is null as: 
-- 1) it is a categorical col and filling it with mean, median, mode can change insights
-- 2) we cannot use methods like bfill or ffill as no pattern persent in data
-- 3) cannot use machine learning here to derive the values by training a model

Delete from sales_trnsc 
where transactiondate is null

select * from sales_trnsc 



