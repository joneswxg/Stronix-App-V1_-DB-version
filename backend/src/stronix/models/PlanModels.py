from datetime import datetime
from typing import List, Optional, Dict, Any
import sqlite3
from ..database import get_db_connection

class TrainingPlan:
    """训练计划模型"""
    
    def __init__(self, id: Optional[int] = None, name: str = "", description: str = "", 
                 difficulty: str = "", duration: int = 0, user_id: Optional[int] = None,
                 is_template: bool = False, template_id: Optional[int] = None,
                 created_at: Optional[datetime] = None, updated_at: Optional[datetime] = None):
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.duration = duration
        self.user_id = user_id
        self.is_template = is_template
        self.template_id = template_id
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'difficulty': self.difficulty,
            'duration': self.duration,
            'user_id': self.user_id,
            'is_template': self.is_template,
            'template_id': self.template_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TrainingPlan':
        """从字典创建实例"""
        return cls(
            id=data.get('id'),
            name=data.get('name', ''),
            description=data.get('description', ''),
            difficulty=data.get('difficulty', ''),
            duration=data.get('duration', 0),
            user_id=data.get('user_id'),
            is_template=data.get('is_template', False),
            template_id=data.get('template_id'),
            created_at=datetime.fromisoformat(data['created_at']) if data.get('created_at') else None,
            updated_at=datetime.fromisoformat(data['updated_at']) if data.get('updated_at') else None
        )

class PlanAction:
    """计划动作模型"""
    
    def __init__(self, plan_id: int, action_id: int, order: int = 1, sets: int = 1,
                 reps: str = "12", rest: int = 60, weight: float = 0.0, 
                 user_id: Optional[int] = None, note: str = "", record_bilateral: bool = False):
        self.plan_id = plan_id
        self.action_id = action_id
        self.order = order
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.weight = weight
        self.user_id = user_id
        self.note = note
        self.record_bilateral = record_bilateral
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'plan_id': self.plan_id,
            'action_id': self.action_id,
            'order': self.order,
            'sets': self.sets,
            'reps': self.reps,
            'rest': self.rest,
            'weight': self.weight,
            'user_id': self.user_id,
            'note': self.note,
            'record_bilateral': self.record_bilateral
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PlanAction':
        """从字典创建实例"""
        return cls(
            plan_id=data['plan_id'],
            action_id=data['action_id'],
            order=data.get('order', 1),
            sets=data.get('sets', 1),
            reps=data.get('reps', "12"),
            rest=data.get('rest', 60),
            weight=data.get('weight', 0.0),
            user_id=data.get('user_id'),
            note=data.get('note', ''),
            record_bilateral=data.get('record_bilateral', False)
        )

class PlanSet:
    """计划组数据模型"""
    
    def __init__(self, id: Optional[int] = None, plan_id: int = 0, action_id: int = 0,
                 set_number: int = 1, weight: float = 0.0, reps: int = 12,
                 left_weight: Optional[float] = None, right_weight: Optional[float] = None,
                 created_at: Optional[datetime] = None):
        self.id = id
        self.plan_id = plan_id
        self.action_id = action_id
        self.set_number = set_number
        self.weight = weight
        self.reps = reps
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.created_at = created_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'id': self.id,
            'plan_id': self.plan_id,
            'action_id': self.action_id,
            'set_number': self.set_number,
            'weight': self.weight,
            'reps': self.reps,
            'left_weight': self.left_weight,
            'right_weight': self.right_weight,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PlanSet':
        """从字典创建实例"""
        return cls(
            id=data.get('id'),
            plan_id=data.get('plan_id', 0),
            action_id=data.get('action_id', 0),
            set_number=data.get('set_number', 1),
            weight=data.get('weight', 0.0),
            reps=data.get('reps', 12),
            left_weight=data.get('left_weight'),
            right_weight=data.get('right_weight'),
            created_at=datetime.fromisoformat(data['created_at']) if data.get('created_at') else None
        )

class Action:
    """动作模型（用于计划中的动作信息）"""
    
    def __init__(self, id: int, name: str, name_en: str = "", gifUrl: str = "",
                 description: str = "", bodypart_id: int = 0, equipment_id: int = 0,
                 is_bilateral: bool = False):
        self.id = id
        self.name = name
        self.name_en = name_en
        self.gifUrl = gifUrl
        self.description = description
        self.bodypart_id = bodypart_id
        self.equipment_id = equipment_id
        self.is_bilateral = is_bilateral
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'id': self.id,
            'name': self.name,
            'name_en': self.name_en,
            'gifUrl': self.gifUrl,
            'description': self.description,
            'bodypart_id': self.bodypart_id,
            'equipment_id': self.equipment_id,
            'is_bilateral': self.is_bilateral
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Action':
        """从字典创建实例"""
        return cls(
            id=data['id'],
            name=data.get('name', ''),
            name_en=data.get('name_en', ''),
            gifUrl=data.get('gifUrl', ''),
            description=data.get('description', ''),
            bodypart_id=data.get('bodypart_id', 0),
            equipment_id=data.get('equipment_id', 0),
            is_bilateral=data.get('is_bilateral', False)
        )

# 错误处理类
class PlanError(Exception):
    """计划相关错误"""
    
    def __init__(self, message: str, code: int = 400, error_key: str = ""):
        self.message = message
        self.code = code
        self.error_key = error_key
        super().__init__(self.message)

# 错误码常量
class PlanErrorCode:
    SUCCESS = 200
    INVALID_REQUEST = 400
    UNAUTHORIZED = 401
    FORBIDDEN = 403
    NOT_FOUND = 404
    CONFLICT = 409
    SERVER_ERROR = 500

# 多语言错误信息
ERROR_MESSAGES = {
    'zh_CN': {
        'PLAN_NAME_EMPTY': '计划名称不能为空',
        'NO_ACTIONS': '请至少添加一个动作',
        'UNAUTHORIZED': '请先登录',
        'PLAN_NOT_FOUND': '计划不存在',
        'ACTION_NOT_FOUND': '动作不存在',
        'PERMISSION_DENIED': '无权限操作此计划',
        'TEMPLATE_NOT_FOUND': '模板计划不存在',
        'INVALID_SET_DATA': '组数据格式错误',
        'SERVER_ERROR': '服务器错误，请稍后重试',
        'PLAN_IN_USE': '计划正在使用中，无法删除'
    },
    'en_US': {
        'PLAN_NAME_EMPTY': 'Plan name cannot be empty',
        'NO_ACTIONS': 'Please add at least one action',
        'UNAUTHORIZED': 'Please login first',
        'PLAN_NOT_FOUND': 'Plan not found',
        'ACTION_NOT_FOUND': 'Action not found',
        'PERMISSION_DENIED': 'Permission denied for this plan',
        'TEMPLATE_NOT_FOUND': 'Template plan not found',
        'INVALID_SET_DATA': 'Invalid set data format',
        'SERVER_ERROR': 'Server error, please try again later',
        'PLAN_IN_USE': 'Plan is in use, cannot be deleted'
    }
}

def get_error_message(error_key: str, language: str = 'zh_CN') -> str:
    """获取错误信息"""
    return ERROR_MESSAGES.get(language, ERROR_MESSAGES['zh_CN']).get(error_key, error_key) 