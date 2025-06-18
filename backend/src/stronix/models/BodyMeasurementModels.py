from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, validator


class BodyMeasurementBase(BaseModel):
    """体测记录基础模型"""
    weight_kg: float = Field(..., gt=0, le=500, description="体重(公斤)")
    height_cm: float = Field(..., gt=0, le=300, description="身高(厘米)")
    body_fat_percentage: float = Field(..., ge=0, le=100, description="体脂百分比")
    skeletal_muscle_mass_kg: float = Field(..., gt=0, le=200, description="骨骼肌量(公斤)")
    visceral_fat_level: int = Field(..., ge=1, le=30, description="内脏脂肪等级")

    @validator('body_fat_percentage')
    def validate_body_fat_percentage(cls, v):
        if v < 0 or v > 50:
            raise ValueError('体脂百分比应在0-50%之间')
        return v

    @validator('skeletal_muscle_mass_kg')
    def validate_muscle_mass(cls, v, values):
        if 'weight_kg' in values and v > values['weight_kg']:
            raise ValueError('骨骼肌量不能超过体重')
        return v


class CreateBodyMeasurementRequest(BodyMeasurementBase):
    """创建体测记录请求模型"""
    user_id: int = Field(..., gt=0, description="用户ID")
    measurement_timestamp: datetime = Field(..., description="测量时间")

    class Config:
        json_encoders = {
            datetime: lambda v: v.strftime('%Y-%m-%d %H:%M:%S')
        }


class UpdateBodyMeasurementRequest(BaseModel):
    """更新体测记录请求模型"""
    weight_kg: Optional[float] = Field(None, gt=0, le=500, description="体重(公斤)")
    height_cm: Optional[float] = Field(None, gt=0, le=300, description="身高(厘米)")
    body_fat_percentage: Optional[float] = Field(None, ge=0, le=100, description="体脂百分比")
    skeletal_muscle_mass_kg: Optional[float] = Field(None, gt=0, le=200, description="骨骼肌量(公斤)")
    visceral_fat_level: Optional[int] = Field(None, ge=1, le=30, description="内脏脂肪等级")


class BodyMeasurementRecord(BodyMeasurementBase):
    """体测记录响应模型"""
    id: int = Field(..., description="记录ID")
    user_id: int = Field(..., description="用户ID")
    measurement_timestamp: datetime = Field(..., description="测量时间")
    created_at: datetime = Field(..., description="创建时间")
    updated_at: datetime = Field(..., description="更新时间")

    # 计算属性
    @property
    def bmi(self) -> float:
        """计算BMI"""
        height_m = self.height_cm / 100
        return round(self.weight_kg / (height_m * height_m), 2)

    @property
    def body_fat_kg(self) -> float:
        """计算体脂肪重量(kg)"""
        return round(self.weight_kg * self.body_fat_percentage / 100, 2)

    def calculate_bmr(self, age: int, gender: str) -> float:
        """计算基础代谢率(BMR) - 使用Katch-McArdle公式"""
        # 计算瘦体重 (Lean Body Mass, LBM)
        # LBM = 体重(kg) * (1 - 体脂百分比 / 100)
        lean_body_mass = self.weight_kg * (1 - self.body_fat_percentage / 100)
        
        # 使用Katch-McArdle公式计算BMR
        # BMR = 370 + (21.6 * LBM)
        bmr = 370 + (21.6 * lean_body_mass)
        
        return round(bmr, 0)

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.strftime('%Y-%m-%d %H:%M:%S')
        }


class BodyMeasurementListResponse(BaseModel):
    """体测记录列表响应模型"""
    measurements: List[BodyMeasurementRecord] = Field(..., description="体测记录列表")
    total_count: int = Field(..., description="总记录数")


class BodyMeasurementDetailResponse(BaseModel):
    """体测记录详情响应模型"""
    measurement: BodyMeasurementRecord = Field(..., description="体测记录详情")


class CreateBodyMeasurementResponse(BaseModel):
    """创建体测记录响应模型"""
    success: bool = Field(True, description="是否成功")
    measurement_id: int = Field(..., description="创建的记录ID")
    message: str = Field("体测记录创建成功", description="响应消息")


class UpdateBodyMeasurementResponse(BaseModel):
    """更新体测记录响应模型"""
    success: bool = Field(True, description="是否成功")
    message: str = Field("体测记录更新成功", description="响应消息")


class DeleteBodyMeasurementResponse(BaseModel):
    """删除体测记录响应模型"""
    success: bool = Field(True, description="是否成功")
    message: str = Field("体测记录删除成功", description="响应消息")


class BodyMeasurementStatistics(BaseModel):
    """体测数据统计模型"""
    latest_measurement: Optional[BodyMeasurementRecord] = Field(None, description="最新记录")
    weight_trend: Optional[float] = Field(None, description="体重趋势(kg)")
    body_fat_trend: Optional[float] = Field(None, description="体脂趋势(%)")
    muscle_mass_trend: Optional[float] = Field(None, description="肌肉量趋势(kg)")
    measurement_count: int = Field(0, description="总记录数")
    date_range_days: int = Field(0, description="记录时间跨度(天)")


class BodyMeasurementQuery(BaseModel):
    """体测记录查询参数模型"""
    user_id: int = Field(..., gt=0, description="用户ID")
    limit: Optional[int] = Field(None, gt=0, le=100, description="限制返回记录数")
    offset: Optional[int] = Field(None, ge=0, description="偏移量")
    start_date: Optional[datetime] = Field(None, description="开始日期")
    end_date: Optional[datetime] = Field(None, description="结束日期")
    order_by: Optional[str] = Field("measurement_timestamp", description="排序字段")
    order_direction: Optional[str] = Field("DESC", description="排序方向(ASC/DESC)")

    @validator('order_direction')
    def validate_order_direction(cls, v):
        if v.upper() not in ['ASC', 'DESC']:
            raise ValueError('排序方向必须是ASC或DESC')
        return v.upper()

    @validator('end_date')
    def validate_date_range(cls, v, values):
        if v and 'start_date' in values and values['start_date'] and v < values['start_date']:
            raise ValueError('结束日期不能早于开始日期')
        return v


# 错误响应模型
class ErrorResponse(BaseModel):
    """错误响应模型"""
    error: str = Field(..., description="错误信息")
    detail: Optional[str] = Field(None, description="详细错误信息")
    code: Optional[str] = Field(None, description="错误代码")


# 成功响应模型
class SuccessResponse(BaseModel):
    """成功响应模型"""
    success: bool = Field(True, description="是否成功")
    message: str = Field(..., description="响应消息")
    data: Optional[dict] = Field(None, description="响应数据") 