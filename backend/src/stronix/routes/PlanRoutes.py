from flask import Blueprint, request, jsonify
from typing import Dict, Any
import traceback
from ..services.PlanService import PlanService
from ..services.AuthService import AuthService
from ..models.PlanModels import PlanError, PlanErrorCode, get_error_message

# 创建蓝图
plan_bp = Blueprint('plan', __name__, url_prefix='/api/plans')

# 创建服务实例
plan_service = PlanService()

def get_current_user_id() -> int:
    """获取当前登录用户ID"""
    # 从请求头获取token
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        raise PlanError(
            get_error_message('UNAUTHORIZED'),
            PlanErrorCode.UNAUTHORIZED,
            'UNAUTHORIZED'
        )
    
    token = auth_header.split(' ')[1]
    user = AuthService.verify_token(token)
    
    if not user:
        raise PlanError(
            get_error_message('UNAUTHORIZED'),
            PlanErrorCode.UNAUTHORIZED,
            'UNAUTHORIZED'
        )
    
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

@plan_bp.route('/templates', methods=['GET'])
def get_template_plans():
    """获取模板计划列表"""
    try:
        language = get_language()
        plans = plan_service.get_template_plans(language)
        
        return jsonify(create_response(
            data=plans,
            message="获取模板计划成功" if language == 'zh_CN' else "Get template plans successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取模板计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/personal', methods=['GET'])
def get_user_plans():
    """获取用户个人计划列表"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        plans = plan_service.get_user_plans(user_id, language)
        
        return jsonify(create_response(
            data=plans,
            message="获取个人计划成功" if language == 'zh_CN' else "Get personal plans successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取个人计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/<int:plan_id>', methods=['GET'])
def get_plan_detail(plan_id: int):
    """获取计划详情"""
    try:
        # 对于模板计划，不需要用户登录
        user_id = None
        try:
            user_id = get_current_user_id()
        except PlanError:
            # 如果没有登录，只能查看模板计划
            pass
        
        language = get_language()
        plan = plan_service.get_plan_detail(plan_id, user_id, language)
        
        return jsonify(create_response(
            data=plan,
            message="获取计划详情成功" if language == 'zh_CN' else "Get plan detail successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"获取计划详情时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/create', methods=['POST'])
def create_plan():
    """创建新的训练计划"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取请求数据
        plan_data = request.get_json()
        if not plan_data:
            raise PlanError(
                get_error_message('INVALID_REQUEST', language),
                PlanErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        # 创建计划
        plan_id = plan_service.create_plan(plan_data, user_id, language)
        
        return jsonify(create_response(
            data={'plan_id': plan_id},
            message="创建计划成功" if language == 'zh_CN' else "Create plan successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"创建计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/copy/<int:template_id>', methods=['POST'])
def copy_template_plan(template_id: int):
    """从模板复制计划"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 复制模板计划
        plan_id = plan_service.copy_template_plan(template_id, user_id, language)
        
        return jsonify(create_response(
            data={'plan_id': plan_id},
            message="复制计划成功" if language == 'zh_CN' else "Copy plan successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"复制计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/<int:plan_id>', methods=['PUT'])
def update_plan(plan_id: int):
    """更新训练计划"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取请求数据
        plan_data = request.get_json()
        if not plan_data:
            raise PlanError(
                get_error_message('INVALID_REQUEST', language),
                PlanErrorCode.INVALID_REQUEST,
                'INVALID_REQUEST'
            )
        
        # 更新计划
        success = plan_service.update_plan(plan_id, plan_data, user_id, language)
        
        return jsonify(create_response(
            data={'success': success},
            message="更新计划成功" if language == 'zh_CN' else "Update plan successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"更新计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/<int:plan_id>', methods=['DELETE'])
def delete_plan(plan_id: int):
    """删除训练计划"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 删除计划
        success = plan_service.delete_plan(plan_id, user_id, language)
        
        return jsonify(create_response(
            data={'success': success},
            message="删除计划成功" if language == 'zh_CN' else "Delete plan successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"删除计划时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

@plan_bp.route('/<int:plan_id>/can_delete', methods=['GET'])
def check_plan_can_delete(plan_id: int):
    """检查计划是否可以删除"""
    try:
        user_id = get_current_user_id()
        language = get_language()
        
        # 获取计划详情来检查权限
        plan = plan_service.get_plan_detail(plan_id, user_id, language)
        
        # 检查是否有进行中的训练会话
        from ..database import get_db_connection
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM training_sessions 
            WHERE plan_id = ? AND user_id = ? AND status = 'in_progress'
        """, (plan_id, user_id))
        
        in_progress_count = cursor.fetchone()[0]
        can_delete = in_progress_count == 0
        
        conn.close()
        
        return jsonify(create_response(
            data={
                'can_delete': can_delete,
                'message': '此计划有未完成的训练会话' if not can_delete else '可以删除'
            },
            message="检查成功" if language == 'zh_CN' else "Check successfully"
        ))
        
    except PlanError as e:
        return jsonify(create_response(
            message=e.message,
            code=e.code
        )), e.code
    except Exception as e:
        print(f"检查计划删除权限时出错: {str(e)}")
        traceback.print_exc()
        return jsonify(create_response(
            message=get_error_message('SERVER_ERROR', get_language()),
            code=PlanErrorCode.SERVER_ERROR
        )), PlanErrorCode.SERVER_ERROR

# 错误处理器
@plan_bp.errorhandler(404)
def not_found(error):
    """404错误处理"""
    language = get_language()
    return jsonify(create_response(
        message=get_error_message('PLAN_NOT_FOUND', language),
        code=PlanErrorCode.NOT_FOUND
    )), PlanErrorCode.NOT_FOUND

@plan_bp.errorhandler(500)
def internal_error(error):
    """500错误处理"""
    language = get_language()
    return jsonify(create_response(
        message=get_error_message('SERVER_ERROR', language),
        code=PlanErrorCode.SERVER_ERROR
    )), PlanErrorCode.SERVER_ERROR 