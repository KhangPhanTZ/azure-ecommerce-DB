use quanlybanhangtructuyen
CREATE INDEX `products_index_category_id` ON `products` (`category_id`);

CREATE INDEX `orders_index_customer_id` ON `orders` (`customer_id`);
CREATE INDEX `orders_index_date` ON `orders` (`date`);
CREATE INDEX `orders_index_employee` ON `orders` (`employee_id`);

CREATE INDEX `reviews_index_product_id` ON `reviews` (`product_id`);

CREATE INDEX `order_detail_index_order_id` ON `order_detail` (`order_id`);
CREATE INDEX `order_detail_index_product_id` ON `order_detail` (`product_id`);

CREATE INDEX `User_index_0` ON `User` (`username`);

CREATE INDEX `Wish_list_index_composite_customer_product` ON `Wish_list` (`customer_id`, `product_id`);

CREATE INDEX `Shopping_cart_index_composite_cus_prod` ON `Shopping_cart` (`customer_id`, `product_id`);

CREATE INDEX `product_storage_index_product_id` ON `product_storage` (`product_id`);
CREATE INDEX `product_storage_index_storage_id` ON `product_storage` (`storage_id`);

CREATE INDEX `bill_index_order_id` ON `bill` (`order_id`);

CREATE INDEX `delivery_index_0` ON `delivery` (`order_id`);

#Tạo full text cho tên và mô tả sản phẩm
ALTER TABLE products ADD FULLTEXT(name, description);

SELECT * FROM products
WHERE MATCH(name, description)
AGAINST('điện thoại thông minh');

select * from products
where match(name,description)
against ('+điện -iphone' in boolean mode);

