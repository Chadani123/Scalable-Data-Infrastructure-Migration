/* On my honor, as an Aggie, I have neither given nor received unauthorized assistance on this assignment. I
further affirm that I have not and will not provide this code to any person, platform, or repository,
without the express written permission of Dr. Gomillion. I understand that any violation of these
standards will have serious repercussions. */

-- Include the previous scripts ( inf.sql, etl.sql, views.sql, proc.sql))
SOURCE proc.sql;

-- Call stored procedures to fill unit prices and order totals
CALL proc_FillUnitPrice();
CALL proc_FillOrderTotal();

-- Create SalesTax table
DROP TABLE IF EXISTS SalesTax;

CREATE TABLE SalesTax (
    zip DECIMAL(5,0) ZEROFILL PRIMARY KEY,
    taxRate DECIMAL(6,5)
) ENGINE=InnoDB;

-- Load data from 'sales_tax_rates.csv' into SalesTax table
-- (Assuming that 'sales_tax_rates.csv' is a CSV file with columns 'zip', 'taxRate')
-- You need to have 'sales_tax_rates.csv' file available

LOAD DATA LOCAL INFILE 'sales_tax_rates.csv'
INTO TABLE SalesTax
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(zip, taxRate);

-- Alter the Order table
-- Rename 'orderTotal' to 'subtotal'
ALTER TABLE `Order`
    CHANGE COLUMN orderTotal subtotal DECIMAL(8,2);

-- Add 'salesTax' column
ALTER TABLE `Order`
    ADD COLUMN salesTax DECIMAL(5,2) DEFAULT 0.00 AFTER subtotal;

-- Add 'total' column as VIRTUAL (subtotal + salesTax)
ALTER TABLE `Order`
    ADD COLUMN total DECIMAL(8,2) AS (subtotal + salesTax) VIRTUAL AFTER salesTax;

-- Change the delimiter to allow for trigger and procedure creation
DELIMITER $$

-- Procedure to update sales tax for an order
CREATE PROCEDURE proc_UpdateSalesTax(IN p_order_id BIGINT UNSIGNED)
BEGIN
    DECLARE v_subtotal DECIMAL(8,2);
    DECLARE v_taxRate DECIMAL(6,5);
    DECLARE v_salesTax DECIMAL(5,2);
    DECLARE v_zip DECIMAL(5,0);
    DECLARE v_customer_id BIGINT UNSIGNED;

    -- Get subtotal and customer_id
    SELECT subtotal, customer_id INTO v_subtotal, v_customer_id FROM `Order` WHERE id = p_order_id;

    -- Get customer's zip
    SELECT zip INTO v_zip FROM Customer WHERE id = v_customer_id;

    -- Get tax rate
    SELECT taxRate INTO v_taxRate FROM SalesTax WHERE zip = v_zip;

    IF v_taxRate IS NULL THEN
        SET v_taxRate = 0.00;
    END IF;

    -- Calculate salesTax using standard rounding
    SET v_salesTax = ROUND(v_subtotal * v_taxRate, 2);

    -- Update salesTax in Order
    UPDATE `Order`
    SET salesTax = v_salesTax
    WHERE id = p_order_id;
END $$

-- Procedure to update mv_CustomerPurchases for a given customer
CREATE PROCEDURE proc_UpdateCustomerPurchases(IN p_CustomerID BIGINT UNSIGNED)
BEGIN
    DELETE FROM mv_CustomerPurchases WHERE `customer number` = p_CustomerID;

    INSERT INTO mv_CustomerPurchases
    SELECT c.id AS 'customer number', 
           c.firstName AS fn, 
           c.lastName AS ln,
           GROUP_CONCAT(CONCAT(p.id, ' ', p.name) ORDER BY p.id SEPARATOR '|') AS products
    FROM Customer c
    LEFT JOIN `Order` o ON c.id = o.customer_id
    LEFT JOIN Orderline ol ON o.id = ol.order_id
    LEFT JOIN Product p ON ol.product_id = p.id
    WHERE c.id = p_CustomerID
    GROUP BY c.id;
END $$

-- Procedure to update mv_ProductBuyers for a given product
CREATE PROCEDURE proc_UpdateProductBuyers(IN p_ProductID BIGINT UNSIGNED)
BEGIN
    DELETE FROM mv_ProductBuyers WHERE productID = p_ProductID;

    INSERT INTO mv_ProductBuyers
    SELECT p.id AS productID, 
           p.name AS productName,
           GROUP_CONCAT(CONCAT(c.id, ' ', c.firstName, ' ', c.lastName) ORDER BY c.id SEPARATOR ',') AS customers
    FROM Product p
    LEFT JOIN Orderline ol ON p.id = ol.product_id
    LEFT JOIN `Order` o ON ol.order_id = o.id
    LEFT JOIN Customer c ON o.customer_id = c.id
    WHERE p.id = p_ProductID
    GROUP BY p.id;
END $$

-- Trigger on Product table to insert into PriceHistory when price changes
CREATE TRIGGER trg_Product_AfterUpdate
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    -- If the currentPrice has changed, insert into PriceHistory
    IF NEW.currentPrice <> OLD.currentPrice THEN
        INSERT INTO PriceHistory (oldPrice, newPrice, product_id)
        VALUES (OLD.currentPrice, NEW.currentPrice, NEW.id);
    END IF;
END $$

-- BEFORE INSERT trigger on Orderline
CREATE TRIGGER trg_Orderline_BeforeInsert
BEFORE INSERT ON Orderline
FOR EACH ROW
BEGIN
    -- If quantity is null or less than 1, set to 1
    IF NEW.quantity IS NULL OR NEW.quantity < 1 THEN
        SET NEW.quantity = 1;
    END IF;

    -- Set unitPrice to currentPrice from Product
    SET NEW.unitPrice = (SELECT currentPrice FROM Product WHERE id = NEW.product_id);

    -- Check if enough quantity is available
    DECLARE v_availableQuantity INT;
    SELECT availableQuantity INTO v_availableQuantity FROM Product WHERE id = NEW.product_id;

    IF NEW.quantity > v_availableQuantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough product quantity available';
    END IF;
END $$

-- BEFORE UPDATE trigger on Orderline
CREATE TRIGGER trg_Orderline_BeforeUpdate
BEFORE UPDATE ON Orderline
FOR EACH ROW
BEGIN
    -- If quantity is null or less than 1, set to 1
    IF NEW.quantity IS NULL OR NEW.quantity < 1 THEN
        SET NEW.quantity = 1;
    END IF;

    -- Prevent changing product_id or order_id
    IF NEW.product_id <> OLD.product_id OR NEW.order_id <> OLD.order_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot change product_id or order_id in Orderline';
    END IF;

    -- Calculate the difference in quantity
    DECLARE v_quantity_diff INT;
    SET v_quantity_diff = NEW.quantity - OLD.quantity;

    -- Check if enough quantity is available
    DECLARE v_availableQuantity INT;
    SELECT availableQuantity INTO v_availableQuantity FROM Product WHERE id = NEW.product_id;

    IF v_quantity_diff > 0 AND v_quantity_diff > v_availableQuantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough product quantity available';
    END IF;
END $$

-- AFTER INSERT trigger on Orderline
CREATE TRIGGER trg_Orderline_AfterInsert
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN
    -- Reduce availableQuantity in Product
    UPDATE Product
    SET availableQuantity = availableQuantity - NEW.quantity
    WHERE id = NEW.product_id;

    -- Update subtotal in Order
    UPDATE `Order`
    SET subtotal = subtotal + NEW.lineTotal
    WHERE id = NEW.order_id;

    -- Update salesTax in Order
    CALL proc_UpdateSalesTax(NEW.order_id);

    -- Update materialized views
    CALL proc_UpdateCustomerPurchases( (SELECT customer_id FROM `Order` WHERE id = NEW.order_id) );
    CALL proc_UpdateProductBuyers(NEW.product_id);
END $$

-- AFTER UPDATE trigger on Orderline
CREATE TRIGGER trg_Orderline_AfterUpdate
AFTER UPDATE ON Orderline
FOR EACH ROW
BEGIN
    DECLARE v_quantity_diff INT;
    DECLARE v_lineTotal_diff DECIMAL(8,2);

    -- Calculate the difference in quantity
    SET v_quantity_diff = NEW.quantity - OLD.quantity;

    -- Update availableQuantity in Product
    UPDATE Product
    SET availableQuantity = availableQuantity - v_quantity_diff
    WHERE id = NEW.product_id;

    -- Calculate the difference in lineTotal
    SET v_lineTotal_diff = NEW.lineTotal - OLD.lineTotal;

    -- Update subtotal in Order
    UPDATE `Order`
    SET subtotal = subtotal + v_lineTotal_diff
    WHERE id = NEW.order_id;

    -- Update salesTax in Order
    CALL proc_UpdateSalesTax(NEW.order_id);

    -- Update materialized views
    CALL proc_UpdateCustomerPurchases( (SELECT customer_id FROM `Order` WHERE id = NEW.order_id) );
    CALL proc_UpdateProductBuyers(NEW.product_id);
END $$

-- AFTER DELETE trigger on Orderline
CREATE TRIGGER trg_Orderline_AfterDelete
AFTER DELETE ON Orderline
FOR EACH ROW
BEGIN
    -- Increase availableQuantity in Product
    UPDATE Product
    SET availableQuantity = availableQuantity + OLD.quantity
    WHERE id = OLD.product_id;

    -- Subtract lineTotal from subtotal in Order
    UPDATE `Order`
    SET subtotal = subtotal - OLD.lineTotal
    WHERE id = OLD.order_id;

    -- Update salesTax in Order
    CALL proc_UpdateSalesTax(OLD.order_id);

    -- Update materialized views
    CALL proc_UpdateCustomerPurchases( (SELECT customer_id FROM `Order` WHERE id = OLD.order_id) );
    CALL proc_UpdateProductBuyers(OLD.product_id);
END $$

-- Reset the delimiter back to the default
DELIMITER ;


























-- CREATE TABLE Product (
--         id int PRIMARY NOT NULL,
--         name VARCHAR(155) NOT NULL,
--         description VARCHAR(255)
-- ) ENGINE=InnoDB;




















