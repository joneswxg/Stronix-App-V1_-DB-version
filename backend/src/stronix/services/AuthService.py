import jwt
import secrets
from datetime import datetime, timedelta
from ..models.UserModel import UserModel

class AuthService:
    # 在实际项目中，这个密钥应该从环境变量获取
    SECRET_KEY = "stronix_secret_key_2024"
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_HOURS = 24
    
    @staticmethod
    def generate_token(user_id):
        """生成JWT token"""
        try:
            payload = {
                'user_id': user_id,
                'exp': datetime.utcnow() + timedelta(hours=AuthService.ACCESS_TOKEN_EXPIRE_HOURS),
                'iat': datetime.utcnow()
            }
            
            token = jwt.encode(payload, AuthService.SECRET_KEY, algorithm=AuthService.ALGORITHM)
            return token
            
        except Exception as e:
            print(f"生成token错误: {e}")
            return None
    
    @staticmethod
    def verify_token(token):
        """验证JWT token"""
        try:
            payload = jwt.decode(token, AuthService.SECRET_KEY, algorithms=[AuthService.ALGORITHM])
            user_id = payload.get('user_id')
            
            if user_id:
                # 验证用户是否仍然存在
                user = UserModel.get_user_by_id(user_id)
                if user:
                    return user
            
            return None
            
        except jwt.ExpiredSignatureError:
            print("Token已过期")
            return None
        except jwt.InvalidTokenError:
            print("无效的token")
            return None
        except Exception as e:
            print(f"验证token错误: {e}")
            return None
    
    @staticmethod
    def register_user(username, email, password, gender=None, height=None, weight=None):
        """用户注册"""
        try:
            # 创建用户
            user, message = UserModel.create_user(username, email, password, gender, height, weight)
            
            if user:
                # 生成token
                token = AuthService.generate_token(user['id'])
                if token:
                    return {
                        'success': True,
                        'message': message,
                        'user': user,
                        'token': token
                    }
                else:
                    return {
                        'success': False,
                        'message': '用户创建成功但token生成失败',
                        'user': None,
                        'token': None
                    }
            else:
                return {
                    'success': False,
                    'message': message,
                    'user': None,
                    'token': None
                }
                
        except Exception as e:
            print(f"注册用户错误: {e}")
            return {
                'success': False,
                'message': f'注册失败: {str(e)}',
                'user': None,
                'token': None
            }
    
    @staticmethod
    def login_user(email, password):
        """用户登录"""
        try:
            # 验证用户
            user, message = UserModel.authenticate_user(email, password)
            
            if user:
                # 生成token
                token = AuthService.generate_token(user['id'])
                if token:
                    return {
                        'success': True,
                        'message': message,
                        'user': user,
                        'token': token
                    }
                else:
                    return {
                        'success': False,
                        'message': '登录成功但token生成失败',
                        'user': None,
                        'token': None
                    }
            else:
                return {
                    'success': False,
                    'message': message,
                    'user': None,
                    'token': None
                }
                
        except Exception as e:
            print(f"登录用户错误: {e}")
            return {
                'success': False,
                'message': f'登录失败: {str(e)}',
                'user': None,
                'token': None
            }
    
    @staticmethod
    def forgot_password(email):
        """忘记密码处理"""
        try:
            # 检查用户是否存在
            user = UserModel.get_user_by_email(email)
            if not user:
                return {
                    'success': False,
                    'message': '该邮箱未注册',
                    'user': None,
                    'token': None
                }
            
            # 生成临时密码（在实际项目中，应该发送邮件而不是直接重置）
            temp_password = secrets.token_urlsafe(8)
            success, message = UserModel.reset_password(email, temp_password)
            
            if success:
                # 在实际项目中，这里应该发送邮件
                print(f"临时密码已生成: {temp_password}")
                return {
                    'success': True,
                    'message': f'密码重置成功，临时密码: {temp_password}',
                    'user': None,
                    'token': None
                }
            else:
                return {
                    'success': False,
                    'message': message,
                    'user': None,
                    'token': None
                }
                
        except Exception as e:
            print(f"忘记密码处理错误: {e}")
            return {
                'success': False,
                'message': f'处理失败: {str(e)}',
                'user': None,
                'token': None
            }
    
    @staticmethod
    def get_current_user(token):
        """根据token获取当前用户"""
        return AuthService.verify_token(token)
    
    @staticmethod
    def change_password(user_id, old_password, new_password):
        """修改密码"""
        try:
            success, message = UserModel.change_password(user_id, old_password, new_password)
            return {
                'success': success,
                'message': message
            }
        except Exception as e:
            print(f"修改密码错误: {e}")
            return {
                'success': False,
                'message': f'修改密码失败: {str(e)}'
            } 