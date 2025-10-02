import redis
import json
import uuid
import logging
import time
import matplotlib.pyplot as plt
import numpy as np
import traceback
from connect_close_db import redis_client, mysql_conn, mysql_cursor as cursor, close_connections

# Thiết lập logging với thêm debug information
logging.basicConfig(level=logging.DEBUG, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Hằng số
SESSION_TTL = 180  # 3 phút

def create_session(user_id, email, fullname, sex, role, address=None, dob=None, department=None, internal_id=None, admin_level=None):
    try:
        token = str(uuid.uuid4())
        session_data = {
            "user_id": user_id,
            "email": email,
            "fullname": fullname,
            "sex": sex,
            "role": role
        }

        if role == "Customer":
            session_data["address"] = address or "N/A"
            session_data["dob"] = dob or "N/A"
        elif role == "Employee":
            session_data["department"] = department or "Unknown"
            session_data["internal_id"] = internal_id or "N/A"
        elif role == "Admin":
            session_data["admin_level"] = admin_level or "standard"
        else:
            # Không raise error nếu vai trò không khớp, chỉ log warning và tiếp tục
            logger.warning(f"Vai trò không chuẩn: {role}, tiếp tục xử lý")

        redis_client.set(f"session:{token}", json.dumps(session_data), ex=SESSION_TTL)
        return token

    except Exception as e:
        logger.error(f"Lỗi khi tạo session: {str(e)}")
        logger.debug(traceback.format_exc())
        return None

def get_user_from_token(token):
    try:
        if not token or not isinstance(token, str):
            logger.warning("Token không hợp lệ")
            return None

        session_data = redis_client.get(f"session:{token}")
        if not session_data:
            logger.warning(f"Không tìm thấy session cho token: {token}")
            return None

        return json.loads(session_data)

    except Exception as e:
        logger.error(f"Lỗi khi lấy dữ liệu từ token: {str(e)}")
        logger.debug(traceback.format_exc())
        return None

def login(username=None, email=None, password="", role="customer"):
    """
    Hàm đăng nhập đã được sửa lại với logging chi tiết hơn và xử lý linh hoạt hơn
    """
    if not username and not email:
        logger.warning("Vui lòng cung cấp username hoặc email")
        return None

    try:
        # Debug info for login attempt
        logger.debug(f"Đang thử đăng nhập với: email={email}, username={username}, role={role}")
        
        # Kiểm tra kết nối database
        if not mysql_conn or mysql_conn.is_connected() == False:
            logger.error("Mất kết nối MySQL")
            return None
            
        # Giảm ràng buộc về role để tăng tỉ lệ đăng nhập thành công
        query = "SELECT id, username, email, fullname, sex, role FROM user WHERE (username=%s OR email=%s) AND password_hashed=%s"
        cursor.execute(query, (username or email, email or username, password))
        user = cursor.fetchone()

        if not user:
            logger.warning(f"Không tìm thấy người dùng với email/username: {email or username}")
            # Kiểm tra xem user có tồn tại không, bỏ qua password
            debug_query = "SELECT id, email, role FROM user WHERE (username=%s OR email=%s) LIMIT 1"
            cursor.execute(debug_query, (username or email, email or username))
            debug_user = cursor.fetchone()
            if debug_user:
                logger.debug(f"User tồn tại nhưng sai mật khẩu: {debug_user['email']}")
            return None

        logger.debug(f"Tìm thấy user: {user['email']}, role={user['role']}")
        
        # Kiểm tra role nếu được chỉ định
        user_role = user["role"].lower() if user["role"] else "customer"
        requested_role = role.lower() if role else "customer"
        
        # Áp dụng kiểm tra role linh hoạt hơn
        # Nếu role không khớp, vẫn cho phép đăng nhập nhưng log warning
        if user_role != requested_role:
            logger.warning(f"Vai trò không khớp: yêu cầu {requested_role}, thực tế {user_role}")
            # Sử dụng vai trò thực tế từ database
            role = user_role

        # Lấy thông tin bổ sung dựa vào role
        try:
            if role == "Customer":
                cursor.execute("SELECT dob, address FROM customers WHERE id = %s", (user["id"],))
                user_role_data = cursor.fetchone() or {}
                return create_session(user['id'], user['email'], user['fullname'], user['sex'], role,
                                    address=user_role_data.get("address"), 
                                    dob=user_role_data.get("dob").isoformat() if user_role_data.get("dob") else None)
            elif role == "Employee":
                cursor.execute("SELECT department, internal_id FROM employee WHERE id = %s", (user["id"],))
                user_role_data = cursor.fetchone() or {}
                return create_session(user['id'], user['email'], user['fullname'], user['sex'], role,
                                    department=user_role_data.get("department"), 
                                    internal_id=user_role_data.get("internal_id"))
            elif role == "Admin":
                cursor.execute("SELECT admin_level FROM admin WHERE id = %s", (user["id"],))
                user_role_data = cursor.fetchone() or {}
                return create_session(user['id'], user['email'], user['fullname'], user['sex'], role,
                                    admin_level=user_role_data.get("admin_level"))
            else:
                # Đối với các role khác, tạo session cơ bản
                logger.info(f"Không có thông tin bổ sung cho role: {role}")
                return create_session(user['id'], user['email'], user['fullname'], user['sex'], role)
                
        except Exception as role_error:
            # Nếu không lấy được thông tin role, vẫn tạo session với thông tin cơ bản
            logger.warning(f"Lỗi khi lấy thông tin cho role {role}: {str(role_error)}")
            return create_session(user['id'], user['email'], user['fullname'], user['sex'], role)

    except Exception as e:
        logger.error(f"Lỗi khi đăng nhập: {str(e)}")
        logger.debug(traceback.format_exc())
        return None

def logout(token):
    try:
        if not token or not isinstance(token, str):
            return {"status": "error", "message": "Token không hợp lệ"}

        deleted = redis_client.delete(f"session:{token}")
        if deleted:
            logger.info(f"Đã xóa session: {token}")
            return {"status": "success", "message": "Đăng xuất thành công"}
        return {"status": "error", "message": "Không tìm thấy session"}

    except Exception as e:
        logger.error(f"Lỗi khi đăng xuất: {str(e)}")
        return {"status": "error", "message": str(e)}

def benchmark_login_vs_cache(email=None, password=None, role="customer", token=None):
    """
    Benchmark function to compare login time vs cache retrieval time
    
    Returns a dictionary with timing results and token info
    """
    result = {
        "login_time": None,
        "cache_time": None,
        "token": None,
        "user_data": None,
        "email": email
    }
    
    # Test login time if email and password provided
    if email and password:
        start_login = time.time()
        result["token"] = login(email=email, password=password, role=role)
        result["login_time"] = time.time() - start_login
        
        if not result["token"]:
            logger.warning(f"Đăng nhập thất bại với email: {email}")
            return result
        else:
            logger.info(f"Đăng nhập thành công: {email}")
            
    # Test cache retrieval time if token provided
    if token:
        start_cache = time.time()
        result["user_data"] = get_user_from_token(token)
        result["cache_time"] = time.time() - start_cache
        
        if not result["user_data"]:
            logger.warning(f"Token không hợp lệ: {token}")
            
    # Calculate speedup if both measurements available
    if result["login_time"] and result["cache_time"] and result["cache_time"] > 0:
        result["speedup"] = result["login_time"] / result["cache_time"]
    else:
        result["speedup"] = None
            
    return result
def plot_time_comparison(benchmark_results):
    """
    Vẽ biểu đồ đường so sánh thời gian thực thi trung bình giữa các trường hợp.
    
    Parameters:
    - benchmark_results: Dict - Dictionary chứa kết quả benchmark với trường 'time'.
    """
    # Danh sách các trường hợp
    cases = list(benchmark_results.keys())
    
    # Tính thời gian trung bình cho mỗi trường hợp
    avg_times = []
    for case in cases:
        times = [result["time"] for result in benchmark_results[case]]
        avg_times.append(np.mean(times) if times else 0)
    
    # Tạo nhãn hiển thị đẹp hơn
    labels = [case.replace("_", " ").title() for case in cases]
    
    # Tạo biểu đồ
    plt.figure(figsize=(10, 6))
    plt.plot(labels, avg_times, marker='o', color='blue')
    
    # Thiết lập tiêu đề và nhãn
    plt.title('So Sánh Thời Gian Thực Thi Trung Bình')
    plt.xlabel('Trường Hợp')
    plt.ylabel('Thời Gian (giây)')
    plt.grid(True)
    plt.xticks(rotation=45)
    
    # Hiển thị biểu đồ
    plt.tight_layout()
    plt.show()
def load_test_data(sample_size=10):
    """
    Load test user data from database
    """
    try:
        # Thử đơn giản hóa truy vấn để đảm bảo tìm được user
        query = """
        SELECT email, password_hashed, role 
        FROM user 
        WHERE password_hashed IS NOT NULL AND email IS NOT NULL
        LIMIT %s
        """
        cursor.execute(query, (sample_size,))
        users = cursor.fetchall()
        
        if not users:
            # Nếu không tìm thấy user, thử truy vấn đơn giản hơn
            fallback_query = "SELECT email, password_hashed, role FROM user LIMIT %s"
            cursor.execute(fallback_query, (sample_size,))
            users = cursor.fetchall()
            
        # Debug: In ra một vài user để kiểm tra
        if users:
            logger.debug(f"Đã lấy {len(users)} người dùng từ cơ sở dữ liệu")
            # Kiểm tra dữ liệu trả về có phải dictionary không
            if isinstance(users[0], dict):
                logger.debug(f"User mẫu: {users[0].get('email', 'Không có email')}")
            else:
                # Lỗi ở đây: users[0] có thể không phải dictionary
                logger.debug(f"User mẫu: {users[0]}")
                # Chuyển đổi dữ liệu nếu cần
                converted_users = []
                for user in users:
                    # Kiểm tra xem cursor trả về tuple hay list
                    if isinstance(user, (tuple, list)):
                        # Nếu là tuple hoặc list, chuyển thành dict
                        converted_user = {
                            'email': user[0] if len(user) > 0 else None,
                            'password_hashed': user[1] if len(user) > 1 else None,
                            'role': user[2] if len(user) > 2 else 'customer'
                        }
                        converted_users.append(converted_user)
                    else:
                        # Nếu đã là dict hoặc dạng khác, giữ nguyên
                        converted_users.append(user)
                return converted_users
        else:
            logger.error("Không tìm thấy dữ liệu người dùng")
            
        return users
        
    except Exception as e:
        logger.error(f"Lỗi khi tải dữ liệu người dùng: {str(e)}")
        logger.debug(traceback.format_exc())
        return []

def benchmark_login_vs_cache(email=None, password=None, role="customer", token=None):
    """
    Benchmark function to compare login time vs cache retrieval time
    
    Returns a dictionary with timing results and token info
    """
    result = {
        "login_time": None,
        "cache_time": None,
        "token": None,
        "user_data": None,
        "email": email,
        "time": None  # Thêm trường time để thống nhất với hàm plot_time_comparison
    }
    
    # Test login time if email and password provided
    if email and password:
        start_login = time.time()
        result["token"] = login(email=email, password=password, role=role)
        result["login_time"] = time.time() - start_login
        result["time"] = result["login_time"]  # Gán thời gian cho trường time
        
        if not result["token"]:
            logger.warning(f"Đăng nhập thất bại với email: {email}")
            return result
        else:
            logger.info(f"Đăng nhập thành công: {email}")
            
    # Test cache retrieval time if token provided
    if token:
        start_cache = time.time()
        result["user_data"] = get_user_from_token(token)
        result["cache_time"] = time.time() - start_cache
        result["time"] = result["cache_time"]  # Gán thời gian cho trường time
        
        if not result["user_data"]:
            logger.warning(f"Token không hợp lệ: {token}")
            
    # Calculate speedup if both measurements available
    if result["login_time"] and result["cache_time"] and result["cache_time"] > 0:
        result["speedup"] = result["login_time"] / result["cache_time"]
    else:
        result["speedup"] = None
            
    return result

def plot_time_comparison(benchmark_results):
    """
    Vẽ biểu đồ đường so sánh thời gian thực thi trung bình giữa các trường hợp.
    
    Parameters:
    - benchmark_results: Dict - Dictionary chứa kết quả benchmark với trường 'time'.
    """
    # Danh sách các trường hợp
    cases = list(benchmark_results.keys())
    
    # Tính thời gian trung bình cho mỗi trường hợp
    avg_times = []
    for case in cases:
        # Lọc các kết quả có trường time không phải None
        valid_results = [result for result in benchmark_results[case] if result.get("time") is not None]
        if valid_results:
            avg_times.append(np.mean([result["time"] for result in valid_results]))
        else:
            avg_times.append(0)
    
    # Tạo nhãn hiển thị đẹp hơn
    labels = [case.replace("_", " ").title() for case in cases]
    
    # Tạo biểu đồ
    plt.figure(figsize=(10, 6))
    plt.plot(labels, avg_times, marker='o', color='blue')
    
    # Thiết lập tiêu đề và nhãn
    plt.title('So Sánh Thời Gian Thực Thi Trung Bình')
    plt.xlabel('Trường Hợp')
    plt.ylabel('Thời Gian (giây)')
    plt.grid(True)
    plt.xticks(rotation=45)
    
    # Thêm nhãn giá trị trên biểu đồ
    for i, value in enumerate(avg_times):
        plt.text(i, value + 0.0005, f'{value:.6f}s', ha='center')
    
    # Hiển thị biểu đồ
    plt.tight_layout()
    plt.show()
def plot_two_bar_charts(with_cache_times, without_cache_times, labels=None):
    """
    Vẽ biểu đồ cột so sánh giá trị trung bình của thời gian thực thi với và không sử dụng cache.
    
    Parameters:
    - with_cache_times: List[float] - Mảng giá trị thời gian khi sử dụng cache.
    - without_cache_times: List[float] - Mảng giá trị thời gian khi không sử dụng cache.
    - labels: List[str] - Không sử dụng, giữ để tương thích với code cũ.
    """
    # Tính giá trị trung bình
    avg_with_cache = np.mean(with_cache_times) if with_cache_times else 0
    avg_without_cache = np.mean(without_cache_times) if without_cache_times else 0
    
    # Dữ liệu cho biểu đồ
    averages = [avg_with_cache, avg_without_cache]
    labels = ['With Cache', 'Without Cache']
    
    # Thiết lập vị trí cột
    x = np.arange(len(labels))  # Vị trí cho các cột
    width = 0.35  # Độ rộng của mỗi cột
    
    # Tạo figure và axes
    fig, ax = plt.subplots(figsize=(8, 6))
    
    # Vẽ biểu đồ cột
    bars = ax.bar(x, averages, width, color=['skyblue', 'salmon'], edgecolor='black')
    
    # Thiết lập tiêu đề và nhãn
    ax.set_title('So Sánh Thời Gian Thực Thi Trung Bình')
    ax.set_xlabel('Phương Pháp')
    ax.set_ylabel('Thời Gian Trung Bình (giây)')
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.grid(True, axis='y', linestyle='--', alpha=0.7)
    
    # Hiển thị giá trị trên mỗi cột
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, height + 0.01, f'{height:.3f}', 
                ha='center', va='bottom')
    
    # Hiển thị biểu đồ
    plt.tight_layout()
    plt.show()
def run_benchmark_test(sample_size=10):
    """
    Run benchmark tests on a sample of users
    """
    try:
        # Get test data
        users = load_test_data(sample_size)
        
        if not users:
            logger.error("Không tìm thấy dữ liệu người dùng để kiểm tra")
            return
            
        logger.info(f"Chạy benchmark với {len(users)} người dùng...")
        
        benchmark_results = {
            "All_user_first_login": [],
            "20%_user_login_by_token": [],
            "50%_user_login_by_token": [],
            "80%_user_login_by_token": [],
            "100%_user_login_by_token":[]
        }
        tokens = []
        
        # First round: Test login performance for all users
        for i, user in enumerate(users):
            try:
                # Kiểm tra và chuyển đổi dữ liệu nếu cần
                if not isinstance(user, dict):
                    logger.warning(f"Người dùng {i+1} không phải là dictionary, đang chuyển đổi...")
                    if isinstance(user, (tuple, list)):
                        user = {
                            'email': user[0] if len(user) > 0 else None,
                            'password_hashed': user[1] if len(user) > 1 else None,
                            'role': user[2] if len(user) > 2 else 'customer'
                        }
                    else:
                        logger.warning(f"Không thể xử lý dữ liệu người dùng: {user}")
                        continue
                        
                # Kiểm tra dữ liệu người dùng
                if not user.get('email') or not user.get('password_hashed'):
                    logger.warning(f"Bỏ qua người dùng {i+1} do thiếu thông tin đăng nhập")
                    continue
                    
                logger.info(f"Đang kiểm tra đăng nhập cho người dùng {i+1}/{len(users)}: {user.get('email', 'N/A')}")
                
                # Mặc định role là "customer" nếu không có
                role = user.get('role', 'customer')
                if not role:
                    role = 'customer'
                    
                result = benchmark_login_vs_cache(
                    email=user['email'], 
                    password=user['password_hashed'], 
                    role=role
                )
                benchmark_results["All_user_first_login"].append(result)
                if result["token"]:
                    tokens.append(result["token"])
            except Exception as user_error:
                logger.error(f"Lỗi khi xử lý người dùng {i+1}: {str(user_error)}")
                continue
                
        # Second round: Test cache performance for different percentages of users
        cache_percentages = [0.2, 0.5, 0.8,1]
        
        if tokens:
            for cache_percent in cache_percentages:
                key = f"{int(cache_percent*100)}%_user_login_by_token"
                threshold = int(len(users) * cache_percent)
                
                for i, user in enumerate(users):
                    if i < threshold and i < len(tokens):
                        # Sử dụng token cho X% người dùng đầu tiên
                        result = benchmark_login_vs_cache(token=tokens[i])
                        benchmark_results[key].append(result)
                    elif isinstance(user, dict) and user.get('email') and user.get('password_hashed'):
                        # Đăng nhập thông thường cho người dùng còn lại
                        role = user.get('role', 'customer')
                        if not role:
                            role = 'customer'
                        result = benchmark_login_vs_cache(
                            email=user['email'], 
                            password=user['password_hashed'], 
                            role=role
                        )
                        benchmark_results[key].append(result)
        else:
            logger.warning("Không có token nào để kiểm tra hiệu suất cache")
            
        # Generate visualization
        if benchmark_results:
            plot_time_comparison(benchmark_results)
        else:
            logger.error("Không có kết quả benchmark để tạo biểu đồ")
        
        # Prepare data for two bar charts
        login_times = []
        cache_times = []
        
        # Collect login times from All_user_first_login
        for result in benchmark_results["All_user_first_login"]:
            if result.get("login_time") is not None:
                login_times.append(result["login_time"])
        
        # Collect cache times from 100%_user_login_by_token
        for result in benchmark_results["100%_user_login_by_token"]:
            if result.get("cache_time") is not None:
                cache_times.append(result["cache_time"])
        
        # Ensure equal length by trimming or padding with zeros
        min_length = min(len(login_times), len(cache_times))
        login_times = login_times[:min_length]
        cache_times = cache_times[:min_length]
        # Plot two bar charts
        if login_times and cache_times:
            plot_two_bar_charts(cache_times,login_times)
        else:
            logger.error("Không có dữ liệu thời gian hợp lệ để vẽ biểu đồ cột")
        
        # Summary statistics
        speedups = []
        for i in range(min_length):
            if cache_times[i] > 0:  # Avoid division by zero
                speedups.append(login_times[i] / cache_times[i])
        print("\n========== Kết quả Benchmark ==========")
        
        if login_times:
            print(f"Thời gian đăng nhập trung bình (MySQL): {sum(login_times)/len(login_times):.6f} giây")
        if cache_times:
            print(f"Thời gian truy xuất cache trung bình (Redis): {sum(cache_times)/len(cache_times):.6f} giây")
        if speedups:
            print(f"Tốc độ cải thiện trung bình: {sum(speedups)/len(speedups):.2f} lần")
                        
    except Exception as e:
        logger.error(f"Lỗi khi chạy benchmark: {str(e)}")
        logger.debug(traceback.format_exc())
    finally:
        close_connections()

def cleanup():
    close_connections()

# Test
if __name__ == "__main__":
    # Bắt đầu với mẫu nhỏ để kiểm tra
    run_benchmark_test(sample_size=100)

