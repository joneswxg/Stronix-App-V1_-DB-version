from flask import Blueprint, request, jsonify
from ..services.AuthService import AuthService

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    """用户注册"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        if not data or not data.get('username') or not data.get('email') or not data.get('password'):
            return jsonify({
                'success': False,
                'message': '用户名、邮箱和密码为必填项',
                'user': None,
                'token': None
            }), 400
        
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        gender = data.get('gender')
        height = data.get('height')
        weight = data.get('weight')
        
        # 基本验证
        if len(password) < 6:
            return jsonify({
                'success': False,
                'message': '密码长度至少6位',
                'user': None,
                'token': None
            }), 400
        
        # 调用认证服务
        result = AuthService.register_user(username, email, password, gender, height, weight)
        
        if result['success']:
            return jsonify(result), 201
        else:
            return jsonify(result), 400
            
    except Exception as e:
        print(f"注册API错误: {e}")
        return jsonify({
            'success': False,
            'message': f'注册失败: {str(e)}',
            'user': None,
            'token': None
        }), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    """用户登录"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({
                'success': False,
                'message': '邮箱和密码为必填项',
                'user': None,
                'token': None
            }), 400
        
        email = data.get('email')
        password = data.get('password')
        
        # 调用认证服务
        result = AuthService.login_user(email, password)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 401
            
    except Exception as e:
        print(f"登录API错误: {e}")
        return jsonify({
            'success': False,
            'message': f'登录失败: {str(e)}',
            'user': None,
            'token': None
        }), 500

@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    """忘记密码"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        if not data or not data.get('email'):
            return jsonify({
                'success': False,
                'message': '邮箱为必填项',
                'user': None,
                'token': None
            }), 400
        
        email = data.get('email')
        
        # 调用认证服务
        result = AuthService.forgot_password(email)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        print(f"忘记密码API错误: {e}")
        return jsonify({
            'success': False,
            'message': f'处理失败: {str(e)}',
            'user': None,
            'token': None
        }), 500

@auth_bp.route('/me', methods=['GET'])
def get_current_user():
    """获取当前用户信息"""
    try:
        # 从请求头获取token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'success': False,
                'message': '未提供认证token',
                'user': None
            }), 401
        
        token = auth_header.split(' ')[1]
        user = AuthService.get_current_user(token)
        
        if user:
            return jsonify({
                'success': True,
                'message': '获取用户信息成功',
                'user': user
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': '无效的token',
                'user': None
            }), 401
            
    except Exception as e:
        print(f"获取用户信息API错误: {e}")
        return jsonify({
            'success': False,
            'message': f'获取用户信息失败: {str(e)}',
            'user': None
        }), 500

@auth_bp.route('/change-password', methods=['POST'])
def change_password():
    """修改密码"""
    try:
        # 从请求头获取token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'success': False,
                'message': '未提供认证token'
            }), 401
        
        token = auth_header.split(' ')[1]
        user = AuthService.get_current_user(token)
        
        if not user:
            return jsonify({
                'success': False,
                'message': '无效的token'
            }), 401
        
        data = request.get_json()
        
        # 验证必需字段
        if not data or not data.get('old_password') or not data.get('new_password'):
            return jsonify({
                'success': False,
                'message': '原密码和新密码为必填项'
            }), 400
        
        old_password = data.get('old_password')
        new_password = data.get('new_password')
        
        # 验证新密码长度
        if len(new_password) < 6:
            return jsonify({
                'success': False,
                'message': '新密码长度至少6位'
            }), 400
        
        # 调用认证服务
        result = AuthService.change_password(user['id'], old_password, new_password)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        print(f"修改密码API错误: {e}")
        return jsonify({
            'success': False,
            'message': f'修改密码失败: {str(e)}'
        }), 500

@auth_bp.route('/logout', methods=['POST'])
def logout():
    """用户登出（客户端处理，服务端只返回成功）"""
    return jsonify({
        'success': True,
        'message': '登出成功'
    }), 200 