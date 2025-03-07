
-- ... [6:22 pm, 1/11/2024] 
-- Ranil Reddy Gaddam Mis Tamu: 


source views.sql





SELECT 
    json_object(
        'Customer Name', CONCAT(cust.firstName, ' ', cust.lastName), 
        'Address', CONCAT(
            cust.address1, 
            IFNULL(CONCAT('\n', cust.address2), ''), 
            '\n', ct.city, ' ', ct.state, ' ', ct.zip
        )
    )
INTO OUTFILE '/var/lib/mysql/POS/cust1.json'
FROM Customer cust 
JOIN City ct ON cust.zip = ct.zip;





SELECT 
    json_object(
        "ProductID", pdt.id, 
        "current price", pdt.currentPrice,
        "name", pdt.name,
        "Customer", JSON_ARRAYAGG(
            JSON_OBJECT(
                "CustomerID", cust.id,
                "Customer Name", CONCAT(cust.firstName, ' ', cust.lastName)
            )
        )
    )
FROM Product pdt
LEFT JOIN Orderline ole ON pdt.id = ole.product_id
LEFT JOIN Order od ON ole.order_id = od.id
LEFT JOIN Customer cust ON cust.id = od.customer_id 
GROUP BY pdt.id, pdt.name
INTO OUTFILE '/var/lib/mysql/POS/prod.json';







SELECT 
    json_object(
        "Order ID", od.id,
        "Order Placed", od.datePlaced,
        "Order Shipped", od.dateShipped,
        "Customer", JSON_OBJECT(
            "CustomerID", cust.id,
            "Customer Name", CONCAT(cust.firstName, ' ', cust.lastName)
        ),
        "Product", JSON_ARRAYAGG(
            JSON_OBJECT(
                "PRODUCT ID", pdt.id,
                "PRODUCT NAME", pdt.name,
                "Quantity", ole.quantity
            )
        )
    )
FROM Order od 
LEFT JOIN Customer cust ON od.customer_id = cust.id 
LEFT JOIN Orderline ole ON ole.order_id = od.id
LEFT JOIN Product pdt ON ole.product_id = pdt.id
GROUP BY od.id
INTO OUTFILE '/var/lib/mysql/POS/ord.json';














SELECT 
    json_object(
        'Customer Name', CONCAT(cust.firstName, ' ', cust.lastName), 
        'Address', CONCAT(
            cust.address1, 
            IFNULL(CONCAT('\n', cust.address2), ''), 
            '\n', ct.city, ' ', ct.state, ' ', ct.zip
        )
    ),
    "Order Details", JSON_ARRAYAGG(
        JSON_OBJECT(
            "Order ID", od.id,
            "Total Order", od.total,
            "Order Place", od.datePlaced,
            "Order Shipped", od.dateShipped, 
            "OrderItems", (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "ProductID", ole.product_id, 
                        "Quantity", ole.quantity, 
                        "ProductName", pdt.name
                    )
                )
                FROM OrderLine ole
                JOIN Product pdt ON ole.product_id = pdt.id 
                WHERE ole.order_id = od.id
            )
        )
    )
FROM Customer cust
JOIN City ct ON cust.zip = ct.zip
INTO OUTFILE '/var/lib/mysql/POS/cust2.json';
