from flask import Blueprint, jsonify, request, send_from_directory
import os
from src.stronix.services.ActionService import (
    get_all_target_muscles, 
    get_all_equipment, 
    get_all_actions,
    get_actions_by_target_muscle
)

action_bp = Blueprint("action", __name__, url_prefix="/api/action")

@action_bp.route("/target_muscle", methods=["GET"])
def list_target_muscles():
    """
    获取所有目标肌肉
    """
    muscles = get_all_target_muscles()
    return jsonify({"result": muscles})

@action_bp.route("/equipment", methods=["GET"])
def list_equipment():
    """
    获取所有训练设备
    """
    equipment = get_all_equipment()
    return jsonify({"result": equipment})

@action_bp.route("/actions", methods=["GET"])
def list_actions():
    """
    获取所有训练动作
    """
    target_muscle_id = request.args.get('target_muscle_id', type=int)
    
    if target_muscle_id:
        actions = get_actions_by_target_muscle(target_muscle_id)
    else:
        actions = get_all_actions()
    
    return jsonify({"result": actions})

# 静态文件服务路由
@action_bp.route("/images/<filename>")
def serve_action_images(filename):
    """
    提供动作图片文件
    """
    # 获取backend目录的绝对路径
    backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
    static_dir = os.path.join(backend_dir, 'static', 'images', 'actions')
    return send_from_directory(static_dir, filename)

# 保持向后兼容的路由
@action_bp.route("/", methods=["GET"])
def list_target_muscles_legacy():
    """
    获取所有目标肌肉 (向后兼容)
    """
    muscles = get_all_target_muscles()
    return jsonify({"result": muscles})
