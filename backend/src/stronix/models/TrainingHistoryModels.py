from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime

# 错误代码定义
class TrainingHistoryErrorCode:
    SUCCESS = 200
    INVALID_REQUEST = 400
    UNAUTHORIZED = 401
    NOT_FOUND = 404
    CONFLICT = 409
    SERVER_ERROR = 500

# 错误消息映射
ERROR_MESSAGES = {
    'zh_CN': {
        'INVALID_REQUEST': '请求参数无效',
        'UNAUTHORIZED': '未授权访问',
        'NOT_FOUND': '资源不存在',
        'CONFLICT': '数据冲突',
        'SERVER_ERROR': '服务器内部错误',
        'PLAN_NOT_FOUND': '训练计划不存在',
        'HISTORY_NOT_FOUND': '训练历史不存在',
        'INVALID_TRAINING_DATA': '训练数据无效',
        'PERMISSION_DENIED': '权限不足'
    },
    'en_US': {
        'INVALID_REQUEST': 'Invalid request parameters',
        'UNAUTHORIZED': 'Unauthorized access',
        'NOT_FOUND': 'Resource not found',
        'CONFLICT': 'Data conflict',
        'SERVER_ERROR': 'Internal server error',
        'PLAN_NOT_FOUND': 'Training plan not found',
        'HISTORY_NOT_FOUND': 'Training history not found',
        'INVALID_TRAINING_DATA': 'Invalid training data',
        'PERMISSION_DENIED': 'Permission denied'
    }
}

def get_error_message(error_key: str, language: str = 'zh_CN') -> str:
    """获取错误消息"""
    return ERROR_MESSAGES.get(language, ERROR_MESSAGES['zh_CN']).get(error_key, error_key)

class TrainingHistoryError(Exception):
    """训练历史相关异常"""
    def __init__(self, message: str, code: int = TrainingHistoryErrorCode.SERVER_ERROR, error_key: str = ''):
        self.message = message
        self.code = code
        self.error_key = error_key
        super().__init__(self.message)

@dataclass
class TrainingHistoryDetail:
    """训练历史详情数据模型"""
    action_id: int
    set_number: int
    weight: Optional[float] = None
    weight_unit: str = "kg"
    reps: Optional[int] = None
    difficulty: Optional[str] = None
    left_weight: Optional[float] = None
    right_weight: Optional[float] = None
    is_completed: bool = False

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'action_id': self.action_id,
            'set_number': self.set_number,
            'weight': self.weight,
            'weight_unit': self.weight_unit,
            'reps': self.reps,
            'difficulty': self.difficulty,
            'left_weight': self.left_weight,
            'right_weight': self.right_weight,
            'is_completed': self.is_completed
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TrainingHistoryDetail':
        """从字典创建实例"""
        return cls(
            action_id=data.get('action_id'),
            set_number=data.get('set_number'),
            weight=data.get('weight'),
            weight_unit=data.get('weight_unit', 'kg'),
            reps=data.get('reps'),
            difficulty=data.get('difficulty'),
            left_weight=data.get('left_weight'),
            right_weight=data.get('right_weight'),
            is_completed=data.get('is_completed', False)
        )

@dataclass
class SaveTrainingHistoryRequest:
    """保存训练历史请求数据模型"""
    plan_id: int
    session_id: int
    plan_name: str
    training_date: str
    plan_description: Optional[str] = None
    volume: float = 0.0
    duration: int = 0
    note: Optional[str] = None
    details: List[TrainingHistoryDetail] = None

    def __post_init__(self):
        if self.details is None:
            self.details = []

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'plan_id': self.plan_id,
            'session_id': self.session_id,
            'plan_name': self.plan_name,
            'plan_description': self.plan_description,
            'training_date': self.training_date,
            'volume': self.volume,
            'duration': self.duration,
            'note': self.note,
            'details': [detail.to_dict() for detail in self.details]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SaveTrainingHistoryRequest':
        """从字典创建实例"""
        details = []
        if 'details' in data and data['details']:
            details = [TrainingHistoryDetail.from_dict(detail) for detail in data['details']]
        
        return cls(
            plan_id=data.get('plan_id'),
            session_id=data.get('session_id'),
            plan_name=data.get('plan_name'),
            plan_description=data.get('plan_description'),
            training_date=data.get('training_date'),
            volume=data.get('volume', 0.0),
            duration=data.get('duration', 0),
            note=data.get('note'),
            details=details
        )

@dataclass
class UpdatePlanSetFromTraining:
    """从训练更新计划组数据模型"""
    weight: Optional[float] = None
    reps: Optional[int] = None
    left_weight: Optional[float] = None
    right_weight: Optional[float] = None
    order: int = 1

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'weight': self.weight,
            'reps': self.reps,
            'left_weight': self.left_weight,
            'right_weight': self.right_weight,
            'order': self.order
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UpdatePlanSetFromTraining':
        """从字典创建实例"""
        return cls(
            weight=data.get('weight'),
            reps=data.get('reps'),
            left_weight=data.get('left_weight'),
            right_weight=data.get('right_weight'),
            order=data.get('order', 1)
        )

@dataclass
class UpdatePlanActionFromTraining:
    """从训练更新计划动作数据模型"""
    action_id: int
    rest: int = 60
    note: str = ""
    record_bilateral: bool = False
    order: int = 1
    sets: List[UpdatePlanSetFromTraining] = None

    def __post_init__(self):
        if self.sets is None:
            self.sets = []

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'action_id': self.action_id,
            'rest': self.rest,
            'note': self.note,
            'record_bilateral': self.record_bilateral,
            'order': self.order,
            'sets': [set_data.to_dict() for set_data in self.sets]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UpdatePlanActionFromTraining':
        """从字典创建实例"""
        sets = []
        if 'sets' in data and data['sets']:
            sets = [UpdatePlanSetFromTraining.from_dict(set_data) for set_data in data['sets']]
        
        return cls(
            action_id=data.get('action_id'),
            rest=data.get('rest', 60),
            note=data.get('note', ''),
            record_bilateral=data.get('record_bilateral', False),
            order=data.get('order', 1),
            sets=sets
        )

@dataclass
class UpdatePlanFromTrainingRequest:
    """从训练更新计划请求数据模型"""
    name: str
    description: Optional[str] = None
    difficulty: Optional[str] = None
    duration: Optional[int] = None
    actions: List[UpdatePlanActionFromTraining] = None

    def __post_init__(self):
        if self.actions is None:
            self.actions = []

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'name': self.name,
            'description': self.description,
            'difficulty': self.difficulty,
            'duration': self.duration,
            'actions': [action.to_dict() for action in self.actions]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UpdatePlanFromTrainingRequest':
        """从字典创建实例"""
        actions = []
        if 'actions' in data and data['actions']:
            actions = [UpdatePlanActionFromTraining.from_dict(action) for action in data['actions']]
        
        return cls(
            name=data.get('name'),
            description=data.get('description'),
            difficulty=data.get('difficulty'),
            duration=data.get('duration'),
            actions=actions
        )

@dataclass
class TrainingHistoryResponse:
    """训练历史响应数据模型"""
    id: int
    plan_id: Optional[int]
    plan_name: str
    training_date: str
    volume: float
    duration: int
    note: Optional[str] = None
    created_at: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'plan_id': self.plan_id,
            'plan_name': self.plan_name,
            'training_date': self.training_date,
            'volume': self.volume,
            'duration': self.duration,
            'note': self.note,
            'created_at': self.created_at
        }

@dataclass
class TrainingHistoryDetailResponse:
    """训练历史详情响应数据模型"""
    history: TrainingHistoryResponse
    details: List[Dict[str, Any]]

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'history': self.history.to_dict(),
            'details': self.details
        } 