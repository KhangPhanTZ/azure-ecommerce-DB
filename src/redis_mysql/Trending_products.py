import json
from threading import Thread
from time import sleep
from datetime import datetime
from connect_close_db import redis_client, mysql_conn, mysql_cursor as cursor, close_connections

def get_trending_products_from_db(mysql_conn):
    """
    Lấy sản phẩm thịnh hành từ MySQL bằng truy vấn SQL.
    Returns:
        List các sản phẩm thịnh hành
    """
    try:
        cursor = mysql_conn.cursor(dictionary=True)
        query = """
            SELECT 
                p.id AS product_id,
                p.name,
                p.price,
                p.description,
                IFNULL(SUM(od.quantity), 0) AS sales_count
            FROM 
                orders,products p
            LEFT JOIN 
                order_detail od ON od.product_id = p.id
            WHERE od.order_id= orders.id and orders.status='received'
            GROUP BY 
                p.id, p.name, p.price, p.description
            ORDER BY 
                sales_count DESC
            LIMIT 100;
        """
        cursor.execute(query)
        products = cursor.fetchall()
        cursor.close()
        return products
    except Exception as e:
        print(f"Error executing SQL to get trending products: {e}")
        return []

def update_trending_cache(redis_client, mysql_conn, update_interval=180):
    """
    Cập nhật cache sản phẩm thịnh hành vào Redis.
    """
    TRENDING_ZSET_KEY = "trending_products_rank"
    TRENDING_HASH_KEY = "trending_products_details"
    
    try:
        products = get_trending_products_from_db(mysql_conn)
        
        redis_client.delete(TRENDING_ZSET_KEY)
        redis_client.delete(TRENDING_HASH_KEY)
        
        for product in products:
            product_key = f"product:{product['product_id']}"
            product_data = json.dumps({
                'name': product['name'],
                'price': float(product['price']),
                'description':product['description'],
                'sales_count': int(product['sales_count'])
            })
            redis_client.hset(TRENDING_HASH_KEY, product_key, product_data)
            redis_client.zadd(TRENDING_ZSET_KEY, {product_key: int(product['sales_count'])})
        
        redis_client.expire(TRENDING_ZSET_KEY, update_interval)
        redis_client.expire(TRENDING_HASH_KEY, update_interval)
        
        print(f"Updated trending products at {datetime.now()}")
        return True
    except Exception as e:
        print(f"Error updating cache: {e}")
        return False

def get_trending_products(redis_client, mysql_conn, limit=10):
    """
    Lấy danh sách sản phẩm thịnh hành từ cache hoặc database.
    """
    TRENDING_ZSET_KEY = "trending_products_rank"
    TRENDING_HASH_KEY = "trending_products_details"
    
    try:
        ranked_keys = redis_client.zrevrange(TRENDING_ZSET_KEY, 0, limit - 1)
        
        if ranked_keys:
            products = []
            count=1 # Top san pham
            for key in ranked_keys:
                product_data = redis_client.hget(TRENDING_HASH_KEY, key)
                if product_data:
                   product = json.loads(product_data)  # không cần decode
                   product["Top"]=count
                   product['product_id'] = int(key.split(':')[1])  # không cần decode
                   products.append(product)
                   count+=1
            return products
        update_trending_cache(redis_client, mysql_conn, update_interval=3600)
        return get_trending_products(redis_client, mysql_conn, limit)
    except Exception as e:
        print(f"Error getting trending products: {e}")
        return []
if __name__ == "__main__": 
    get_trending_products_from_db(mysql_conn)
    products = get_trending_products(redis_client, mysql_conn)
    for item in  products:
        print(item)
    close_connections()
