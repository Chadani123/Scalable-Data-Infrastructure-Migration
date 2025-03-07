

/* On my honor, as an Aggie, I have neither given nor received unauthorized assistance on this assignment. I
further affirm that I have not and will not provide this code to any person, platform, or repository,
without the express written permission of Dr. Gomillion. I understand that any violation of these
standards will have serious repercussions. */

SOURCE views.sql; -- Loading the ETL data (which includes inf.sql)

-- SQL select statement to generate the first aggregate:
-- Focuses on Customers
-- Includes all address information
-- Does not include Address2 if it is NULL
-- Combines Address1, Address2, City, State, and Zip into a single field with \n between lines Address1 and Address2, and between Address2 and everything else
-- Combines First and Last Name and provides it as “Customer Name”
-- Ends with INTO OUTFILE to output the JSON objects into a single file called cust1.json


-- Delete the existing file if it exists (running this in the terminal)
-- rm -f /var/lib/mysql/POS/cust1.json;


SELECT 
    JSON_OBJECT(
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Address', CONCAT(
            c.address1,
            IF(c.address2 IS NOT NULL AND c.address2 != '', CONCAT('\n', c.address2), ''),
            '\n', ct.city, ', ', ct.state, ' ', c.zip)
    ) AS json_output
FROM Customer c
JOIN City ct ON c.zip = ct.zip
INTO OUTFILE '/var/lib/mysql/POS/cust1.json'
FIELDS TERMINATED BY ''
LINES TERMINATED BY '\n';


-- Note: JSON viewers/processors automatically display \\n as an actual newline. 
-- Aobve code generates \\n, for fixing this I have another code which just replaces \\n with \n if that is required. 

-- SELECT 
--     JSON_OBJECT(
--         'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
--         'Address', REPLACE(CONCAT(
--             c.address1,
--             IF(c.address2 IS NOT NULL AND c.address2 != '', CONCAT('\n', c.address2), ''),
--             '\n', ct.city, ', ', ct.state, ' ', c.zip
--         ), '\\n', '\n')
--     ) AS json_output
-- FROM Customer c
-- JOIN City ct ON c.zip = ct.zip
-- INTO OUTFILE '/var/lib/mysql/POS/cust1.json'
-- FIELDS TERMINATED BY ''
-- LINES TERMINATED BY '\n';




-- JSON_OBJECT creates a JSON object for each customer.
-- 'Customer Name' combines firstName and lastName.
-- 'Address' concatenates address1, optionally address2 (only if it's not NULL or empty), and the city, state, and zip, separated by \n where specified.
-- INTO OUTFILE outputs the JSON objects into cust1.json in the default directory.
-- FIELDS TERMINATED BY '' ensures no additional characters between fields.
-- LINES TERMINATED BY '\n' writes each JSON object on a new line without commas between them.




-- SQL select statement to generate the second aggregate:

-- Focuses on products and who purchased them
-- Includes ProductID, current price, and product name
-- Includes an array of customers that purchased the product
-- Each customer is an object that includes CustomerID and Customer Name (first name + “ ” + last name)
-- Output into prod.json

SELECT 
    JSON_OBJECT(
        'ProductID', p.id,
        'ProductName', p.name,
        'CurrentPrice', p.currentPrice,
        'Customers', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'CustomerID', c.id,
                    'Customer Name', CONCAT(c.firstName, ' ', c.lastName)
                )
            ) FROM Orderline ol
            JOIN `Order` o ON ol.order_id = o.id
            JOIN Customer c ON o.customer_id = c.id
            WHERE ol.product_id = p.id
        )
    ) AS json_output
FROM Product p
INTO OUTFILE '/var/lib/mysql/POS/prod.json';
-- FIELDS TERMINATED BY ''
-- LINES TERMINATED BY '\n';


-- JSON_OBJECT constructs a JSON object for each product.
-- Product details include ProductID, ProductName, and CurrentPrice.
-- Customers field is an array of customer objects who purchased the product.
-- JSON_ARRAYAGG aggregates customer JSON objects into an array.
-- Subquery fetches customers who purchased the product.
-- Joins are used to link Product, Orderline, Order, and Customer tables.
-- INTO OUTFILE writes the output to prod.json.



-- SQL select statement to generate the third aggregate:

-- Focuses on orders
-- Each order represented, with buyer object and product object
-- Includes quantity
-- Output into ord.json

-- SELECT 
--     JSON_OBJECT(
--         'OrderID', o.id,
--         'Buyer', JSON_OBJECT(
--             'CustomerID', c.id,
--             'Customer Name', CONCAT(c.firstName, ' ', c.lastName)
--         ),
--         'Items', (
--             SELECT JSON_ARRAYAGG(
--                 JSON_OBJECT(
--                     'ProductID', p.id,
--                     'ProductName', p.name,
--                     'Quantity', ol.quantity
--                 )
--             ) FROM Orderline ol
--             JOIN Product p ON ol.product_id = p.id
--             WHERE ol.order_id = o.id
--         )
--     ) AS json_output
-- FROM `Order` o
-- JOIN Customer c ON o.customer_id = c.id
-- INTO OUTFILE '/var/lib/mysql/POS/ord.json';


SELECT 
    JSON_OBJECT(
        'OrderID', o.id,
        'Buyer', JSON_OBJECT(
            'CustomerID', c.id,
            'Customer Name', CONCAT(c.firstName, ' ', c.lastName)
        ),
        'Products', JSON_ARRAYAGG(
            JSON_OBJECT(
                'ProductID', p.id,
                'Product Name', p.name,
                'Quantity', ol.quantity
            )
        )
    )
INTO OUTFILE '/var/lib/mysql/POS/ord.json'
FROM `Order` o
JOIN Customer c ON o.customer_id = c.id
JOIN Orderline ol ON o.id = ol.order_id
JOIN Product p ON ol.product_id = p.id
GROUP BY o.id;

-- FIELDS TERMINATED BY ''
-- LINES TERMINATED BY '\n';


-- JSON_OBJECT creates a JSON object for each order.
-- Buyer field is a JSON object containing buyer's CustomerID and Customer Name.
-- Items field is an array of products in the order with ProductID, ProductName, and Quantity.
-- Subquery within Items selects products for each order.
-- INTO OUTFILE outputs to ord.json.






ALTER TABLE Orderline
ADD unitPrice DECIMAL(6,2),
ADD lineTotal DECIMAL(8,2) GENERATED ALWAYS AS (quantity * unitPrice) VIRTUAL;



ALTER TABLE `Order`
ADD orderTotal DECIMAL(8,2);





UPDATE Orderline ol
JOIN Product p ON ol.product_id = p.id
SET ol.unitPrice = p.currentPrice
WHERE ol.unitPrice IS NULL;



UPDATE `Order` o
JOIN (
    SELECT order_id, SUM(lineTotal) AS total
    FROM Orderline
    GROUP BY order_id
) ol ON o.id = ol.order_id
SET o.orderTotal = ol.total
WHERE o.orderTotal IS NULL;





-- SQL select statement to generate the fourth aggregate:

-- Focuses on Customers and their orders
-- Includes all information from cust1.json
-- Adds in an array of each order placed by the customer, including:
-- Order Total
-- Order Date
-- Shipping Date
-- Items in the order
-- Product ID
-- Quantity
-- Product Name
-- Output into cust2.json

SELECT 
    JSON_OBJECT(
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Address', CONCAT(
            c.address1,
            IF(c.address2 IS NOT NULL AND c.address2 != '', CONCAT('\n', c.address2), ''),
            '\n', city.city, ', ', city.state, ' ', c.zip),
        'Orders', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'OrderID', o.id,
                    'OrderTotal', o.orderTotal,
                    'OrderDate', o.datePlaced,
                    'ShippingDate', o.dateShipped,
                    'Items', (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'ProductID', p.id,
                                'ProductName', p.name,
                                'Quantity', ol.quantity
                            )
                        ) FROM Orderline ol
                        JOIN Product p ON ol.product_id = p.id
                        WHERE ol.order_id = o.id
                    )
                )
            ) FROM `Order` o
            WHERE o.customer_id = c.id
        )
    ) AS json_output
FROM Customer c
JOIN City city ON c.zip = city.zip
INTO OUTFILE '/var/lib/mysql/POS/cust2.json';
-- FIELDS TERMINATED BY ''
-- LINES TERMINATED BY '\n';


-- Starts with customer information as in cust1.json.
-- Orders field is an array of orders for each customer.
-- Each order object includes OrderID, OrderTotal, OrderDate, ShippingDate.
-- Items within each order is an array of products with ProductID, ProductName, Quantity.
-- Nested subqueries are used to build arrays of orders and items.
-- INTO OUTFILE outputs the result to cust2.json.



-- Create one aggregate that will be useful in answering a question. 
-- It must use data across multiple tables, and it must include a nested document. 
-- Create a comment that describes the question, and then store the results into a file called custom.json.



-- Question: For each product, provide its price history over time.

SELECT 
    JSON_OBJECT(
        'ProductID', p.id,
        'ProductName', p.name,
        'CurrentPrice', p.currentPrice,
        'PriceHistory', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'OldPrice', ph.oldPrice,
                    'NewPrice', ph.newPrice,
                    'Timestamp', ph.ts
                )
            ) FROM PriceHistory ph
            WHERE ph.product_id = p.id
            ORDER BY ph.ts
        )
    ) AS json_output
FROM Product p
INTO OUTFILE '/var/lib/mysql/POS/custom.json';
-- FIELDS TERMINATED BY ''
-- LINES TERMINATED BY '\n';



-- Purpose: To provide a historical view of price changes for each product.
-- PriceHistory field is an array of price change records.
-- Each price history object includes OldPrice, NewPrice, and Timestamp.
-- Subquery selects price history entries for each product, ordered by timestamp.
-- Uses data from multiple tables: Product and PriceHistory.
-- Includes nested documents in the form of the PriceHistory array.
-- INTO OUTFILE outputs to custom.json.

