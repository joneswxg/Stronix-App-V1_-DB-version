from flask import Blueprint, request, jsonify
from typing import Dict, Any
import traceback
from ..services.TrainingHistoryService import TrainingHistoryService
from ..services.AuthService import AuthService
from ..models.TrainingHistoryModels import TrainingHistoryError, TrainingHistoryErrorCode, get_error_message

# 创建蓝图
training_history_bp = Blueprint('training_history', __name__, url_prefix='/api/training')

# 创建服务实例
training_history_service = TrainingHistoryService()

def get_current_user_id() -> int:
    """获取当前登录用户ID"""
    # 从请求头获取token
    auth_header = request.headers.get('Authorization')
    print(f"🔍 认证头: {auth_header}")
    
    if not auth_header or not auth_header.startswith('Bearer '):
        print("❌ 认证头格式错误或缺失")
        raise TrainingHistoryError(
            get_error_message('UNAUTHORIZED'),
            TrainingHistoryErrorCode.UNAUTHORIZED,
            'UNAUTHORIZED'
        )
    
    token = auth_header.split(' ')[1]
    print(f"🔑 提取的token: {token[:20]}...")
    
    user = AuthService.verify_token(token)
    print(f"👤 验证结果: {user}")
    
    if not user:
        print("❌ Token验证失败")
        raise TrainingHistoryError(
            get_error_message('UNAUTHORIZED'),
            TrainingHistoryErrorCode.UNAUTHORIZED,
            'UNAUTHORIZED'
        )
    
    print(f"✅ 用户验证成功，用户ID: {user['id']}")
    return user['id']

def get_language() -> str:
    """获取请求语言"""
    return request.headers.get('Accept-Language', 'zh_CN')

def create_response(data: Any = None, message: str = "", code: int = 200) -> Dict[str, Any]:
    """创建统一的响应格式"""
    response = {
        'code': code,
        'message': message
    }
    if data is not None:
        response['data'] = data
    return response

@training_history_bp.route('/history', methods=['POST'])
def save_training_history():
    """保存训练历史"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取请求数据
        history_data = request.get_json()
        if not history_data:
            raise TrainingHistoryError(
                get_error_message('INVALID_REQUEST', language),
                TrainingHistoryErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        # 保存训练历史
        history_id = training_history_service.save_training_history(history_data, user_id, language)
        
        return jsonify(create_response(
            data={'history_id': history_id},
            message="保存训练历史成功" if language == 'zh_CN' else "Save training history successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"保存训练历史时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/plans/<int:plan_id>/update-from-training', methods=['PUT'])
def update_plan_from_training(plan_id: int):
    """从训练更新计划"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取请求数据
        plan_data = request.get_json()
        if not plan_data:
            raise TrainingHistoryError(
                get_error_message('INVALID_REQUEST', language),
                TrainingHistoryErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        # 更新计划
        training_history_service.update_plan_from_training(plan_id, plan_data, user_id, language)
        
        return jsonify(create_response(
            message="更新训练计划成功" if language == 'zh_CN' else "Update training plan successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"更新训练计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/history', methods=['GET'])
def get_training_history():
    """获取训练历史列表"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取查询参数
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 20, type=int)
        plan_id = request.args.get('plan_id', type=int)
        start_date = request.args.get('start_date', type=str)
        end_date = request.args.get('end_date', type=str)
        
        print(f"🔍 获取训练历史请求参数: page={page}, limit={limit}, plan_id={plan_id}, start_date={start_date}, end_date={end_date}")
        
        # 获取训练历史
        history_list = training_history_service.get_training_history(user_id, page, limit, plan_id, start_date, end_date, language)
        
        return jsonify(create_response(
            data=history_list,
            message="获取训练历史成功" if language == 'zh_CN' else "Get training history successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取训练历史时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/training-dates', methods=['GET'])
def get_training_dates():
    """获取指定日期范围内有训练记录的日期列表"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取查询参数
        start_date = request.args.get('start_date', type=str)
        end_date = request.args.get('end_date', type=str)
        
        if not start_date or not end_date:
            raise TrainingHistoryError(
                get_error_message('INVALID_REQUEST', language),
                TrainingHistoryErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        print(f"🗓️ 获取训练日期请求参数: start_date={start_date}, end_date={end_date}")
        
        # 获取训练日期
        training_dates = training_history_service.get_training_dates(user_id, start_date, end_date, language)
        
        return jsonify(create_response(
            data=training_dates,
            message="获取训练日期成功" if language == 'zh_CN' else "Get training dates successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取训练日期时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/history/<int:history_id>', methods=['GET'])
def get_training_history_detail(history_id: int):
    """获取训练历史详情"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取训练历史详情
        history_detail = training_history_service.get_training_history_detail(history_id, user_id, language)
        
        return jsonify(create_response(
            data=history_detail,
            message="获取训练历史详情成功" if language == 'zh_CN' else "Get training history detail successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取训练历史详情时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/history/<int:history_id>', methods=['DELETE'])
def delete_training_history(history_id: int):
    """删除训练历史"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 删除训练历史
        training_history_service.delete_training_history(history_id, user_id, language)
        
        return jsonify(create_response(
            message="删除训练历史成功" if language == 'zh_CN' else "Delete training history successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"删除训练历史时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/statistics', methods=['GET'])
def get_training_statistics():
    """获取训练统计数据"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取查询参数
        time_range = request.args.get('time_range', 'week', type=str)
        
        print(f"📊 获取训练统计请求参数: time_range={time_range}")
        
        # 获取训练统计
        statistics = training_history_service.get_training_statistics(user_id, time_range, language)
        
        return jsonify(create_response(
            data=statistics,
            message="获取训练统计成功" if language == 'zh_CN' else "Get training statistics successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取训练统计时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.route('/action-progress', methods=['GET'])
def get_action_progress():
    """获取特定动作的进步数据"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取查询参数
        action_name = request.args.get('action_name', type=str)
        
        if not action_name:
            raise TrainingHistoryError(
                get_error_message('INVALID_REQUEST', language),
                TrainingHistoryErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        print(f"💪 获取动作进步请求参数: action_name={action_name}")
        
        # 获取动作进步数据
        progress = training_history_service.get_action_progress(user_id, action_name, language)
        
        return jsonify(create_response(
            data=progress,
            message="获取动作进步数据成功" if language == 'zh_CN' else "Get action progress successfully"
        ))
        
    except TrainingHistoryError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取动作进步数据时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=TrainingHistoryErrorCode.SERVER_ERROR
        )), TrainingHistoryErrorCode.SERVER_ERROR

@training_history_bp.errorhandler(404)
def not_found(error):
    """404错误处理"""
    return jsonify(create_response(
        message=get_error_message('NOT_FOUND', get_language()),
        code=TrainingHistoryErrorCode.NOT_FOUND
    )), TrainingHistoryErrorCode.NOT_FOUND

@training_history_bp.errorhandler(500)
def internal_error(error):
    """500错误处理"""
    return jsonify(create_response(
        message=get_error_message('SERVER_ERROR', get_language()),
        code=TrainingHistoryErrorCode.SERVER_ERROR
    )), TrainingHistoryErrorCode.SERVER_ERROR 