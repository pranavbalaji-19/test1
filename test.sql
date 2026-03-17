SELECT 
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    categories.category_name,
    SUM(order_items.quantity * products.price) AS total_sales_revenue
FROM 
    customers
JOIN 
    orders ON customers.customer_id = orders.customer_id
JOIN 
    order_items ON orders.order_id = order_items.order_id
JOIN 
    products ON order_items.product_id = products.product_id
JOIN 
    categories ON products.category_id = categories.category_id
WHERE 
    categories.category_name = 'Electronics'
GROUP BY 
    customers.customer_id, customers.first_name, customers.last_name, categories.category_name
ORDER BY 
    total_sales_revenue DESC;
