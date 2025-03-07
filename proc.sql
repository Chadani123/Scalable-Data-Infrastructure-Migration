-- Loading the ETL data (which includes inf.sql, etl.sql)
SOURCE views.sql;


-- 2. Making some structural Changes to the Database.

-- 2.a. ALTER the Orderline table to add a column called unitPrice of type DECIMAL(6,2)
ALTER TABLE Orderline
    ADD COLUMN unitPrice DECIMAL(6,2) AFTER quantity;

-- 2.b. ALTER the Orderline table to add a column called lineTotal of type DECIMAL(8,2)
-- that is a virtual generated column, made up of quantity * unitPrice
ALTER TABLE Orderline
    ADD COLUMN lineTotal DECIMAL(8,2) 
    AS (quantity * unitPrice) VIRTUAL AFTER unitPrice;

-- 2.c. ALTER the Order table to add a column called orderTotal that is of type DECIMAL(8,2)
ALTER TABLE `Order`
    ADD COLUMN orderTotal DECIMAL(8,2) AFTER customer_id;

-- 2.d. ALTER the Customer table to drop the phone column
ALTER TABLE Customer
    DROP COLUMN phone;

-- 2.e. MODIFY the PriceHistory table's ts column
ALTER TABLE PriceHistory
    MODIFY COLUMN ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP() ON UPDATE CURRENT_TIMESTAMP();





-- 3.0 Create Stored Procedures

-- Utility: Drop procedures if they already exist to avoid errors
DROP PROCEDURE IF EXISTS proc_FillUnitPrice;
DROP PROCEDURE IF EXISTS proc_FillOrderTotal;
DROP PROCEDURE IF EXISTS proc_RefreshMV;
DROP PROCEDURE IF EXISTS proc_AddItem;
DROP PROCEDURE IF EXISTS proc_SalesReport;
DROP PROCEDURE IF EXISTS proc_UpdatePrice;

-- 3. Procedure to fill null unitPrice in Orderline with currentPrice from Product
DELIMITER //

CREATE PROCEDURE proc_FillUnitPrice()
BEGIN
    UPDATE Orderline ol
    LEFT JOIN Product p ON ol.product_id = p.id
    SET ol.unitPrice = p.currentPrice
    WHERE ol.unitPrice IS NULL;
END //

DELIMITER ;

-- 4. Procedure to fill orderTotal in Order table with sum of lineTotal from Orderline
DELIMITER //

CREATE PROCEDURE proc_FillOrderTotal()
BEGIN
    UPDATE `Order` o
    JOIN (
        SELECT order_id, SUM(lineTotal) AS total
        FROM Orderline
        GROUP BY order_id
    ) ol_sum ON o.id = ol_sum.order_id
    SET o.orderTotal = ol_sum.total
    WHERE o.orderTotal IS NULL;
END //

DELIMITER ;


-- 5. Procedure to refresh materialized views safely

DELIMITER //

CREATE PROCEDURE proc_RefreshMV()
BEGIN
    -- Refresh mv_ProductBuyers
    START TRANSACTION;
        DELETE FROM mv_ProductBuyers;
        INSERT INTO mv_ProductBuyers
        SELECT * FROM v_ProductBuyers;
    COMMIT;

    -- Refresh mv_CustomerPurchases
    START TRANSACTION;
        DELETE FROM mv_CustomerPurchases;
        INSERT INTO mv_CustomerPurchases
        SELECT * FROM v_CustomerPurchases;
    COMMIT;
END //

DELIMITER ;





-- 6. Procedure to add a new Orderline, update availableQuantity and orderTotal
DELIMITER //

CREATE PROCEDURE proc_AddItem(
    IN p_OrderID BIGINT UNSIGNED,
    IN p_ProductID BIGINT UNSIGNED,
    IN p_Quantity INTEGER
)
BEGIN
    DECLARE v_CurrentPrice DECIMAL(6,2);
    DECLARE v_Total DECIMAL(8,2);

    -- Start transaction
    START TRANSACTION;

        -- Get currentPrice from Product
        SELECT currentPrice INTO v_CurrentPrice FROM Product WHERE id = p_ProductID;

        -- Insert new Orderline
        INSERT INTO Orderline (order_id, product_id, quantity, unitPrice)
        VALUES (p_OrderID, p_ProductID, p_Quantity, v_CurrentPrice);

        -- Decrement availableQuantity in Product
        UPDATE Product
        SET availableQuantity = availableQuantity - p_Quantity
        WHERE id = p_ProductID;

        -- Update orderTotal in Order table
        SELECT orderTotal INTO v_Total FROM `Order` WHERE id = p_OrderID;
        IF v_Total IS NULL THEN
            -- If orderTotal is NULL, calculate it
            CALL proc_FillOrderTotal();
        ELSE
            -- If orderTotal exists, add the new lineTotal
            UPDATE `Order` 
            SET orderTotal = orderTotal + (p_Quantity * v_CurrentPrice)
            WHERE id = p_OrderID;
        END IF;

    COMMIT;
END //

DELIMITER ;




-- 7. Procedure to generate sales report

-- Change the delimiter to allow for procedure creation
DELIMITER //

CREATE PROCEDURE proc_SalesReport(
    IN p_startDate DATE,
    IN p_endDate DATE,
    IN p_productID BIGINT UNSIGNED
)
BEGIN
    -- Select the Product ID, total quantity sold, and total sales amount
    SELECT 
        p.id AS `Product ID`,
        SUM(ol.quantity) AS `Quantity Sold`,
        SUM(ol.lineTotal) AS `Total Sales Amount`
    FROM 
        Product p
    LEFT JOIN 
        Orderline ol ON p.id = ol.product_id
    LEFT JOIN 
        `Order` o ON ol.order_id = o.id 
    WHERE 
        p.id = p_productID
        AND o.datePlaced BETWEEN p_startDate AND p_endDate;
END //

-- Reset the delimiter back to the default
DELIMITER ;




-- 8. Procedure to update product price and log history
DELIMITER //

CREATE PROCEDURE proc_UpdatePrice(
    IN p_ProductID BIGINT UNSIGNED,
    IN p_NewPrice DECIMAL(6,2)
)
BEGIN
    DECLARE v_OldPrice DECIMAL(6,2);

    -- Start transaction
    START TRANSACTION;

        -- Get current price
        SELECT currentPrice INTO v_OldPrice FROM Product WHERE id = p_ProductID;

        -- Update Product price
        UPDATE Product
        SET currentPrice = p_NewPrice
        WHERE id = p_ProductID;

        -- Insert into PriceHistory
        INSERT INTO PriceHistory (oldPrice, newPrice, product_id)
        VALUES (v_OldPrice, p_NewPrice, p_ProductID);

    COMMIT;
END //

DELIMITER ;