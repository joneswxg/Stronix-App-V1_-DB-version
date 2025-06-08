from datetime import datetime
from ..extensions import db

# 训练计划和动作的关联表
class PlanAction(db.Model):
    __tablename__ = 'plan_actions'
    
    plan_id = db.Column(db.Integer, db.ForeignKey('training_plans.id'), primary_key=True)
    action_id = db.Column(db.Integer, db.ForeignKey('action.id'), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    order = db.Column(db.Integer)  # 动作顺序
    sets = db.Column(db.Integer)   # 组数
    reps = db.Column(db.Integer)   # 次数
    weight = db.Column(db.Float)   # 重量
    rest = db.Column(db.Integer)   # 休息时间（秒）
    note = db.Column(db.String(255))  # 备注
    record_bilateral = db.Column(db.Boolean, default=False)  # 修改为record_bilateral
    
    # 关系
    plan = db.relationship('TrainingPlan', backref='plan_action_links')
    action = db.relationship('Action', backref='plan_action_links')
    user = db.relationship('User', backref='plan_actions')

# 训练计划组数据表
class PlanSet(db.Model):
    __tablename__ = 'plan_sets'
    
    id = db.Column(db.Integer, primary_key=True)
    plan_id = db.Column(db.Integer, db.ForeignKey('training_plans.id'), nullable=False)
    action_id = db.Column(db.Integer, db.ForeignKey('action.id'), nullable=False)
    set_number = db.Column(db.Integer, nullable=False)  # 组号
    weight = db.Column(db.Float)  # 重量
    left_weight = db.Column(db.Float)  # 左侧重量
    right_weight = db.Column(db.Float)  # 右侧重量
    reps = db.Column(db.Integer)  # 次数
    
    # 关系
    plan = db.relationship('TrainingPlan', backref='plan_sets')
    action = db.relationship('Action', backref='plan_sets')

class TrainingPlan(db.Model):
    __tablename__ = 'training_plans'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)  # 允许为空
    difficulty = db.Column(db.String(20), nullable=True)  # 允许为空
    duration = db.Column(db.Integer, nullable=True)  # 允许为空
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关联用户（创建者）
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    user = db.relationship('User', backref=db.backref('training_plans', lazy=True))
    
    # 关联动作（多对多）
    actions = db.relationship(
        'Action',
        secondary='plan_actions',  # 字符串引用表名
        primaryjoin='TrainingPlan.id == PlanAction.plan_id',
        secondaryjoin='PlanAction.action_id == Action.id',
        viewonly=True,
        backref=db.backref('plans', lazy=True)
    )
    
    # 是否是模板
    is_template = db.Column(db.Boolean, default=False)
    # 如果这个计划是从模板创建的，记录模板ID
    template_id = db.Column(db.Integer, db.ForeignKey('training_plans.id'), nullable=True)
    
    def __repr__(self):
        return f'<TrainingPlan {self.name}>'
    
    def to_dict(self):
        """转换为字典格式"""
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'difficulty': self.difficulty,
            'duration': self.duration,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
            'user_id': self.user_id,
            'is_template': self.is_template,
            'template_id': self.template_id
        }
    
    def copy_from_template(self):
        """从模板创建新的训练计划"""
        if not self.is_template:
            raise ValueError("只能从模板创建计划")
            
        new_plan = TrainingPlan(
            name=f"{self.name} - 副本",
            description=self.description,
            difficulty=self.difficulty,
            duration=self.duration,
            user_id=self.user_id,
            is_template=False,
            template_id=self.id
        )
        
        # 复制动作关联
        for action in self.actions:
            new_plan.actions.append(action)
            
        return new_plan
