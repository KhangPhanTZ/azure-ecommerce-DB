-- Lập trình view 
DELIMITER //
-- Tạo view để lấy thông tin đơn hàng đầy đủ
CREATE VIEW view_order_full_info AS
SELECT 
    o.id AS order_id,
    o.date AS order_date,
    o.status,
    o.total_amount,
    c.id AS customer_id,
    c.address,
    u.fullname AS employee_name,
    p.name AS product_name,
    od.quantity,
    od.unit_price,
    d.discount_code AS discount_applied
FROM orders o
JOIN customers c ON o.customer_id = c.id
LEFT JOIN User u ON o.employee_id = u.id
JOIN order_detail od ON o.id = od.order_id
JOIN products p ON od.product_id = p.id
LEFT JOIN discount d ON od.discount_product_id = d.id;
select * from view_order_full_info WHERE order_id = 1;
---------------------------------------------------------------
-- Lấy thông tin sản phẩm và số lượng tồn kho trong kho hàng
CREATE VIEW view_product_inventory AS
SELECT 
    ps.product_id AS product_id,
    p.name AS product_name,
    ps.storage_id,
    s.city AS warehouse_city,
    ps.inventory
FROM product_storage ps
JOIN products p ON ps.product_id = p.id
JOIN Storage s ON ps.storage_id = s.id;
Select * from view_product_inventory WHERE warehouse_city = 'Đà Nẵng';
Select * from view_product_inventory WHERE product_id = 1;
----------------------------------------------------------------
-- Lấy thông tin sản phẩm và đánh giá của khách hàng
CREATE VIEW view_reviews AS
SELECT 
    r.product_id,
    p.name AS product_name,
    r.customer_id,
    r.rating,
    r.content,
    r.date
FROM reviews r
JOIN products p ON r.product_id = p.id;
SELECT * FROM view_reviews WHERE product_id = 1;
----------------------------------------------------------------
-- Lấy thông tin khách hàng 
CREATE VIEW view_customer_info AS
SELECT 
    c.id AS customer_id,
    u.fullname,
    u.email,
    c.address,
    u.sex,
    c.Dob as date_of_birth,
    u.created_date,
    c.loyalty_points
FROM customers c 
JOIN User u ON c.id = u.id
WHERE u.role = 'customer';


-----------------------------------------------------------------------------
-- Lấy thông tin hóa đơn 
CREATE VIEW view_bill_summary AS
SELECT 
    b.id AS bill_id,
    b.order_id,
    b.transaction_id,
    b.create_date,
    b.status,
    b.payment_method,
    u.fullname AS employee_name,
    SUM(od.unit_price * od.quantity) AS total_bill_amount
FROM bill b
JOIN orders o ON b.order_id = o.id
JOIN User u ON o.employee_id = u.id
JOIN order_detail od ON od.order_id = b.order_id
GROUP BY b.id, b.order_id, b.transaction_id, b.create_date, b.status, b.payment_method, u.fullname;

---------------------------------------------------------------------------

-- Lấy thông tin của nhân viên employee và admin 
CREATE VIEW view_user_employee_admin AS
SELECT
    u.id AS user_id,
    u.username,
    u.fullname,
    u.role,
    u.created_date,
    u.updated_date,
    e.department,
    e.internal_id,
    e.hire_date,
    NULL AS admin_level,
    NULL AS granted_date
FROM User u
JOIN employee e ON u.id = e.id
WHERE u.role = 'employee'

UNION ALL

SELECT
    u.id AS user_id,
    u.username,
    u.fullname,
    u.role,
    u.created_date,
    u.updated_date,
    NULL AS department,
    NULL AS internal_id,
    NULL AS hire_date,
    a.admin_level,
    a.granted_date
FROM User u
JOIN admin a ON u.id = a.id
WHERE u.role = 'admin';


