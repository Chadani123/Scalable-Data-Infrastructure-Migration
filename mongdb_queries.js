// MongoDB Milestone Queries

// 1. Find customers who live in Texas
print("\nQuery 1: Customers in Texas");
db.Customers.find({"Address": /Texas/i}).forEach(printjson);

// 2. Find the best customer based on total spending
print("\nQuery 2: Best Customer");
db.CustomerOrders.aggregate([
    { $group: { _id: "$Customer Name", totalSpent: { $sum: "$Order Total" } } },
    { $sort: { totalSpent: -1 } },
    { $limit: 1 }
]).forEach(printjson);

// 3. Find the best product based on the number of purchases
print("\nQuery 3: Best Product");
db.Products.aggregate([
    { $unwind: "$Customers" },
    { $group: { _id: "$ProductID", purchases: { $sum: 1 } } },
    { $sort: { purchases: -1 } },
    { $limit: 1 }
]).forEach(printjson);

// 4. Find products that should be considered for discontinuation (no purchases)
print("\nQuery 4: Products with No Purchases (Consider for Discontinuation)");
db.Products.find({ "Customers": { $size: 0 } }).forEach(printjson);

// 5. Find customers who purchased a specific product (for recall purposes)
const productIdForRecall = "<product_id>";  // Replace with actual product ID
print("\nQuery 5: Customers Who Purchased a Product (for Recall)");
db.Orders.find(
    { "Items.ProductID": productIdForRecall },
    { "Buyer.CustomerID": 1, "Buyer.Customer Name": 1 }
).forEach(printjson);

// 6. Detect potentially fraudulent orders
print("\nQuery 6: Potentially Fraudulent Orders");
db.Orders.find({
    $or: [
        { "Order Total": { $gt: 10000 } },  // Adjust threshold as needed
        { "Items": { $size: { $gt: 10 } } }  // Adjust size as needed
    ]
}).forEach(printjson);

// 7. Custom query based on previous milestone question (top 10 customers by total spending)
print("\nQuery 7: Top 10 Customers by Total Spending");
db.CustomerOrders.aggregate([
    { $group: { _id: "$Customer Name", totalSpent: { $sum: "$Order Total" } } },
    { $sort: { totalSpent: -1 } },
    { $limit: 10 }
]).forEach(printjson);

print("\nAll queries completed.");
