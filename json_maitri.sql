
source views.sql;

SELECT 
    JSON_OBJECT(
        'Customer Name', CONCAT(Customer.firstName, ' ', Customer.lastName),
        'Address', CONCAT(
            Customer.address1, '\n',
            IF(Customer.address2 IS NOT NULL, CONCAT(Customer.address2, '\n'), ''),
            City.city, ', ', City.state, ' ', LPAD(City.zip, 5, '0')
        )
    ) 
INTO OUTFILE '/var/lib/mysql/POS/cust1.json'
FROM Customer
JOIN City ON Customer.zip = City.zip;







SELECT 
    JSON_OBJECT(
        'ProductID', p.id,
        'Product Name', p.name,
        'Current Price', p.currentPrice,
        'Customers', JSON_ARRAYAGG(
            JSON_OBJECT('CustomerID', c.id, 'Customer Name', CONCAT(c.firstName, ' ', c.lastName))
        )
    )
INTO OUTFILE '/var/lib/mysql/POS/prod.json'
FROM Product p
LEFT JOIN Orderline ol ON p.id = ol.product_id
LEFT JOIN `Order` o ON ol.order_id = o.id
LEFT JOIN Customer c ON o.customer_id = c.id
GROUP BY p.id;







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




SELECT 
    JSON_OBJECT(
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Address', CONCAT_WS('\n', c.address1, IFNULL(c.address2, ''), CONCAT(ci.city, ', ', ci.state, ' ', LPAD(ci.zip, 5, '0'))),
        'Orders', JSON_ARRAYAGG(
            JSON_OBJECT(
                'OrderID', o.id,
                'Order Total', o.orderTotal,
                'Order Date', o.datePlaced,
                'Shipping Date', o.dateShipped,
                'Items', (SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'ProductID', p.id,
                                    'Product Name', p.name,
                                    'Quantity', ol.quantity
                                )
                            )
                            FROM Orderline ol
                            JOIN Product p ON ol.product_id = p.id
                            WHERE ol.order_id = o.id
                        )
            )
        )
    )
INTO OUTFILE '/var/lib/mysql/POS/cust2.json'
FROM Customer c
JOIN City ci ON c.zip = ci.zip
LEFT JOIN `Order` o ON c.id = o.customer_id
GROUP BY c.id;




/*
    Business Question:
    Who are our top 10 customers based on total spending, and what are the details of their purchases?
    
    This aggregate helps identify the most valuable customers, understand their purchasing patterns,
    and tailor marketing strategies to enhance customer loyalty and increase sales.
*/




SELECT
    JSON_OBJECT(
        'CustomerID', c.id,
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Total Spent', SUM(o.orderTotal),
        'Orders', JSON_ARRAYAGG(
            JSON_OBJECT(
                'OrderID', o.id,
                'Order Total', o.orderTotal,
                'Order Date', o.datePlaced,
                'Shipping Date', o.dateShipped,
                'Items', (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'ProductID', p.id,
                            'Product Name', p.name,
                            'Quantity', ol.quantity,
                            'Unit Price', ol.unitPrice,
                            'Line Total', ol.lineTotal
                        )
                    )
                    FROM Orderline ol
                    JOIN Product p ON ol.product_id = p.id
                    WHERE ol.order_id = o.id
                )
            )
        )
    )
INTO OUTFILE '/var/lib/mysql/POS/custom.json'
FROM Customer c
JOIN `Order` o ON c.id = o.customer_id
GROUP BY c.id
ORDER BY SUM(o.orderTotal) DESC
LIMIT 10;


