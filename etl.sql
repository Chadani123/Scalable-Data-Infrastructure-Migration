
-- This line includes the inf.sql script to create tables
SOURCE inf.sql;

-- Drop and recreate the Product table;
DROP TABLE IF EXISTS TempProduct;

CREATE TABLE TempProduct (
    id INT,
    name VARCHAR(128),
    price VARCHAR(50),
    quantity_on_hand VARCHAR(50)
) ENGINE=InnoDB;

-- Load the CSV file into the TempProduct table
LOAD DATA LOCAL INFILE 'products.csv'
INTO TABLE TempProduct
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, name, price, quantity_on_hand);

-- Transform and insert data from TempProduct to Product table
INSERT INTO Product (id, name, currentPrice, availableQuantity)
SELECT
    id,
    name,
    -- Replace $ and commas, remove any surrounding quotes, then convert to DECIMAL(6,2)
    CAST(REPLACE(REPLACE(REPLACE(price, '$', ''), ',', ''), '"', '') AS DECIMAL(6,2)),
    -- Ensure quantity is a valid integer, set to NULL if invalid
    CASE
        WHEN quantity_on_hand REGEXP '^[0-9]+$' THEN CAST(quantity_on_hand AS UNSIGNED)
        ELSE NULL
    END AS availableQuantity
FROM
    TempProduct
WHERE
    -- Ensure that mandatory fields are not empty
    name IS NOT NULL AND name != '';


-- Clean up temporary table
DROP TABLE IF EXISTS TempProduct;



-- ************************************************* --
-- ************************************************* --
-- ************************************************* --



-- Clean up the temporary table
DROP TABLE IF EXISTS TempCustomer;

-- Creating the Temporary Customer Table to load the Data from CSV file
-- Temporarily store as VARCHAR to handle reformatting

CREATE TABLE TempCustomer (
    Id INT,
    FirstName VARCHAR(32),
    LastName VARCHAR(30),
    city VARCHAR(32),
    `state` VARCHAR(4),
    ZIP DECIMAL(5,0) ZEROFILL,
    Address1 VARCHAR(100),
    Address2 VARCHAR(50),
    Email VARCHAR(128),
    Birthdate VARCHAR(50) 
) ENGINE=InnoDB;

-- Loading the data into the temp table which was created above
LOAD DATA LOCAL INFILE 'customers.csv'
INTO TABLE TempCustomer
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Id, FirstName, LastName, city, `state`, ZIP, Address1, Address2, Email, Birthdate);


-- Populating City Table
INSERT INTO City (zip, city, `state`)
SELECT DISTINCT
    CASE 
        WHEN ZIP REGEXP '^[0-9]{5}$' THEN CAST(ZIP AS DECIMAL(5,0))
        ELSE NULL 
    END AS ZIP,
    NULLIF(City, '') AS City,
    NULLIF(`state`, '') AS `state`
FROM TempCustomer
WHERE
    ZIP IS NOT NULL 
    AND City IS NOT NULL 
    AND `state` IS NOT NULL;



-- Populating Customer Table


INSERT INTO Customer (id, firstName, lastName, email, address1, address2, phone, birthdate, zip)
SELECT
    id, 
    NULLIF(FirstName, '') AS FirstName,
    NULLIF(LastName, '') AS LastName,
    NULLIF(Email, '') AS Email,
    NULLIF(Address1, '') AS Address1,
    NULLIF(Address2, '') AS Address2, 
    NULL AS Phone, -- Set Phone as NULL since phone numbers are missing
    -- Use STR_TO_DATE to reformat Birthdate, check against '0000-00-00'
    CASE
        WHEN Birthdate = '0000-00-00' OR STR_TO_DATE(Birthdate, '%m/%d/%Y') IS NULL OR Birthdate = '' OR STR_TO_DATE(Birthdate, '%m/%d/%Y') = '00-00-0000' THEN NULL
        ELSE STR_TO_DATE(Birthdate, '%m/%d/%Y')
    END AS Birthdate,
    CASE 
        WHEN ZIP REGEXP '^[0-9]{5}$' THEN CAST(ZIP AS DECIMAL(5,0))
        ELSE NULL 
    END AS ZIP
FROM
    TempCustomer;





DROP TABLE IF EXISTS TempCustomer;




-- ************************************************* --
-- ************************************************* --
-- ************************************************* --




-- Create a temporary table to load raw data
DROP TABLE IF EXISTS TempOrder;

CREATE TABLE TempOrder (
    id INT,
    customerId INT,
    orderDate VARCHAR(20),
    dateShipped VARCHAR(20)
) ENGINE=InnoDB;

-- Load the CSV data into the TempOrder table
LOAD DATA LOCAL INFILE 'orders.csv'
INTO TABLE TempOrder
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, customerId, orderDate, dateShipped);

-- Transform and insert data into the Order table

INSERT INTO `Order` (id, customer_id, datePlaced, dateShipped)
SELECT 
    id,
    customerId,
    CASE 
        WHEN orderDate = '0000-00-00' OR orderDate = '' OR STR_TO_DATE(orderDate, '%Y-%m-%d %H:%i:%s') = '0000-00-00' THEN NULL
        ELSE DATE(STR_TO_DATE(orderDate, '%Y-%m-%d %H:%i:%s'))
    END AS datePlaced,
    
    CASE 
        WHEN dateShipped = '0000-00-00' OR dateShipped = '' OR dateShipped = 'Cancelled' OR STR_TO_DATE(dateShipped, '%Y-%m-%d %H:%i:%s') = '0000-00-00' THEN NULL
        ELSE DATE(STR_TO_DATE(dateShipped, '%Y-%m-%d %H:%i:%s'))
    END AS dateShipped
FROM 
    TempOrder
WHERE 
    customerId IN (SELECT id FROM Customer);



DROP TABLE IF EXISTS TempOrder;



-- ************************************************* --
-- ************************************************* --
-- ************************************************* --


-- Create a temporary table to load raw data
DROP TABLE IF EXISTS TempOrderLine;

CREATE TABLE TempOrderLine (
    orderId INT,
    productId INT,
    quantity INT
) ENGINE=InnoDB;

-- Load the CSV data into the TempOrderLine table
LOAD DATA LOCAL INFILE 'orderlines.csv'
INTO TABLE TempOrderLine
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(orderId, productId, quantity);

-- Transform and insert data into the OrderLine table

INSERT INTO Orderline (order_id, product_id, quantity)
SELECT 
    orderId,
    productId,
    COUNT(*) AS quantity  -- Count occurrences to determine the quantity
FROM 
    TempOrderLine
WHERE 
    orderId IN (SELECT id FROM `Order`)
GROUP BY 
    orderId, productId
ON DUPLICATE KEY UPDATE
    quantity = VALUES(quantity);


DROP TABLE IF EXISTS TempOrderLine;



-- ************************************************* --
-- ************************************************* --
-- ************************************************* --