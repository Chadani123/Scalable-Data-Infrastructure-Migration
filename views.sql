-- Loading the ETL data (which includes inf.sql)
SOURCE etl.sql; 



-- 1. Creating a list of customers sorted by last name, first name in v_customers.
CREATE OR REPLACE VIEW v_customers AS
SELECT lastName AS 'Last Name', firstName AS 'First Name'
FROM Customer
ORDER BY lastName, firstName;



-- 2. Creating a list of customers with full address sorted by zip code in v_customers2.
CREATE OR REPLACE VIEW v_customers2 AS
SELECT id AS customer_number, 
       firstName AS first_name, 
       lastName AS last_name, 
       CONCAT(address1, IFNULL(CONCAT(', ', address2), '')) AS addr1,
       CONCAT(city, ', ', `state`, '   ', City.zip) AS addr2
FROM Customer
JOIN City ON Customer.zip = City.zip  -- This JOIN fetches city and state based on zip
ORDER BY City.zip;



-- 3. Creating a list of customers who bought each product.
-- CREATE OR REPLACE VIEW v_ProductBuyers AS
-- SELECT p.id AS productID, 
--        p.name AS productName,
--        GROUP_CONCAT(CONCAT(c.id, ' ', c.firstName, ' ', c.lastName) ORDER BY c.id SEPARATOR ',') AS customers
-- FROM Product p
-- LEFT JOIN Orderline ol ON p.id = ol.product_id
-- LEFT JOIN `Order` o ON ol.order_id = o.id
-- LEFT JOIN Customer c ON o.customer_id = c.id
-- GROUP BY p.id
-- ORDER BY p.id;


CREATE OR REPLACE VIEW v_ProductBuyers AS
SELECT p.id AS productID, 
       p.name AS productName,
       GROUP_CONCAT(DISTINCT c.id, ' ', c.firstName, ' ', c.lastName ORDER BY c.id SEPARATOR ',') AS customers
FROM Product p
LEFT JOIN Orderline ol ON p.id = ol.product_id
LEFT JOIN `Order` o ON ol.order_id = o.id
LEFT JOIN Customer c ON o.customer_id = c.id
GROUP BY p.id
ORDER BY p.id;



-- 4. Creating a list of products each customer bought.
-- CREATE OR REPLACE VIEW v_CustomerPurchases AS
-- SELECT c.id AS 'customer number', 
--        c.firstName AS fn, 
--        c.lastName AS ln,
--        GROUP_CONCAT(CONCAT(p.id, ' ', p.name) ORDER BY p.id SEPARATOR '|') AS products
-- FROM Customer c
-- LEFT JOIN `Order` o ON c.id = o.customer_id
-- LEFT JOIN Orderline ol ON o.id = ol.order_id
-- LEFT JOIN Product p ON ol.product_id = p.id
-- GROUP BY c.id
-- ORDER BY c.lastName, c.firstName;


CREATE OR REPLACE VIEW v_CustomerPurchases AS
SELECT c.id AS 'customer number', 
       c.firstName AS fn, 
       c.lastName AS ln,
       GROUP_CONCAT(DISTINCT p.id, ' ', p.name ORDER BY p.id SEPARATOR '|') AS products
FROM Customer c
LEFT JOIN `Order` o ON c.id = o.customer_id
LEFT JOIN Orderline ol ON o.id = ol.order_id
LEFT JOIN Product p ON ol.product_id = p.id
GROUP BY c.id
ORDER BY c.lastName, c.firstName;



-- 5. Creating Materialized View for v_ProductBuyers
-- 5. Creating Materialized View for v_CustomerPurchases

DROP TABLE IF EXISTS mv_ProductBuyers;
DROP TABLE IF EXISTS mv_CustomerPurchases;

CREATE TABLE mv_ProductBuyers AS
SELECT * FROM v_ProductBuyers;

CREATE TABLE mv_CustomerPurchases AS
SELECT * FROM v_CustomerPurchases;

-- Since we're using CREATE TABLE AS SELECT, the table will not have any explicit primary key or indexes unless we define them separately 
-- When using CREATE TABLE AS SELECT, MariaDB automatically assigns the appropriate data types based on the source view (v_ProductBuyers or v_CustomerPurchases).



-- 6. Creating Index on Customer Email
-- Attempt to drop the existing index on Customer email if it exists
DROP INDEX IF EXISTS idx_CustomerEmail ON Customer;

CREATE INDEX idx_CustomerEmail ON Customer(email);


-- 7. Creating Index on Product Name
-- Attempt to drop the existing index on Product name if it exists
DROP INDEX IF EXISTS idx_ProductName ON Product;

CREATE INDEX idx_ProductName ON Product(name);