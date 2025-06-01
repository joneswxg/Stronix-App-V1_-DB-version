from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from ..services.database.db_service import get_db_connection

class UserModel:
    @staticmethod
    def create_user(username, email, password, gender=None, height=None, weight=None):
        """创建新用户"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 检查用户是否已存在
            cursor.execute("SELECT id FROM user WHERE email = ? OR username = ?", (email, username))
            if cursor.fetchone():
                return None, "用户已存在"
            
            # 创建密码哈希
            password_hash = generate_password_hash(password)
            
            # 插入新用户
            cursor.execute("""
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at)
                VALUES (?, ?, ?, ?, ?, ?, 'regular', 0, ?)
            """, (username, email, password_hash, gender, height, weight, datetime.now().isoformat()))
            
            user_id = cursor.lastrowid
            conn.commit()
            
            # 获取创建的用户信息
            user = UserModel.get_user_by_id(user_id)
            return user, "用户创建成功"
            
        except Exception as e:
            print(f"创建用户错误: {e}")
            return None, f"创建用户失败: {str(e)}"
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def authenticate_user(email, password):
        """验证用户登录"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT id, username, email, password_hash, gender, height, weight, role, is_admin, created_at
                FROM user WHERE email = ?
            """, (email,))
            
            user_data = cursor.fetchone()
            if not user_data:
                return None, "用户不存在"
            
            # 验证密码
            if not check_password_hash(user_data[3], password):
                return None, "密码错误"
            
            # 构建用户对象
            user = {
                'id': user_data[0],
                'username': user_data[1],
                'email': user_data[2],
                'gender': user_data[4],
                'height': user_data[5],
                'weight': user_data[6],
                'role': user_data[7],
                'is_admin': bool(user_data[8]),
                'created_at': user_data[9]
            }
            
            return user, "登录成功"
            
        except Exception as e:
            print(f"用户认证错误: {e}")
            return None, f"认证失败: {str(e)}"
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def get_user_by_id(user_id):
        """根据ID获取用户信息"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT id, username, email, gender, height, weight, role, is_admin, created_at
                FROM user WHERE id = ?
            """, (user_id,))
            
            user_data = cursor.fetchone()
            if not user_data:
                return None
            
            return {
                'id': user_data[0],
                'username': user_data[1],
                'email': user_data[2],
                'gender': user_data[3],
                'height': user_data[4],
                'weight': user_data[5],
                'role': user_data[6],
                'is_admin': bool(user_data[7]),
                'created_at': user_data[8]
            }
            
        except Exception as e:
            print(f"获取用户信息错误: {e}")
            return None
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def get_user_by_email(email):
        """根据邮箱获取用户信息"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT id, username, email, gender, height, weight, role, is_admin, created_at
                FROM user WHERE email = ?
            """, (email,))
            
            user_data = cursor.fetchone()
            if not user_data:
                return None
            
            return {
                'id': user_data[0],
                'username': user_data[1],
                'email': user_data[2],
                'gender': user_data[3],
                'height': user_data[4],
                'weight': user_data[5],
                'role': user_data[6],
                'is_admin': bool(user_data[7]),
                'created_at': user_data[8]
            }
            
        except Exception as e:
            print(f"获取用户信息错误: {e}")
            return None
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def update_user(user_id, **kwargs):
        """更新用户信息"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 构建更新语句
            update_fields = []
            values = []
            
            for field, value in kwargs.items():
                if field in ['username', 'email', 'gender', 'height', 'weight']:
                    update_fields.append(f"{field} = ?")
                    values.append(value)
            
            if not update_fields:
                return False, "没有要更新的字段"
            
            values.append(user_id)
            query = f"UPDATE user SET {', '.join(update_fields)} WHERE id = ?"
            
            cursor.execute(query, values)
            conn.commit()
            
            if cursor.rowcount > 0:
                return True, "用户信息更新成功"
            else:
                return False, "用户不存在"
                
        except Exception as e:
            print(f"更新用户信息错误: {e}")
            return False, f"更新失败: {str(e)}"
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def change_password(user_id, old_password, new_password):
        """修改密码"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 获取当前密码哈希
            cursor.execute("SELECT password_hash FROM user WHERE id = ?", (user_id,))
            result = cursor.fetchone()
            
            if not result:
                return False, "用户不存在"
            
            # 验证旧密码
            if not check_password_hash(result[0], old_password):
                return False, "原密码错误"
            
            # 更新新密码
            new_password_hash = generate_password_hash(new_password)
            cursor.execute("UPDATE user SET password_hash = ? WHERE id = ?", 
                         (new_password_hash, user_id))
            conn.commit()
            
            return True, "密码修改成功"
            
        except Exception as e:
            print(f"修改密码错误: {e}")
            return False, f"修改密码失败: {str(e)}"
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def reset_password(email, new_password):
        """重置密码（用于忘记密码功能）"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 检查用户是否存在
            cursor.execute("SELECT id FROM user WHERE email = ?", (email,))
            if not cursor.fetchone():
                return False, "用户不存在"
            
            # 更新密码
            password_hash = generate_password_hash(new_password)
            cursor.execute("UPDATE user SET password_hash = ? WHERE email = ?", 
                         (password_hash, email))
            conn.commit()
            
            return True, "密码重置成功"
            
        except Exception as e:
            print(f"重置密码错误: {e}")
            return False, f"重置密码失败: {str(e)}"
        finally:
            if conn:
                conn.close() 