# 训练计划 API 文档

## 概述
训练计划API提供了创建、管理和使用训练计划的功能，包括模板计划和个人计划的管理。

## 基础信息
- 基础URL: `http://localhost:6000/api/plans`
- 认证方式: Session（需要先登录）
- 响应格式: JSON

## 通用响应格式
```json
{
    "code": 200,
    "message": "操作成功",
    "data": {}
}
```

## API 接口

### 1. 获取模板计划列表
获取所有可用的模板计划。

**请求**
```
GET /api/plans/templates
```

**请求头**
```
Accept-Language: zh_CN  # 可选，默认为zh_CN
```

**响应示例**
```json
{
    "code": 200,
    "message": "获取模板计划成功",
    "data": [
        {
            "id": 1,
            "name": "新手入门计划",
            "description": "适合健身新手的基础训练计划",
            "difficulty": "初级",
            "duration": 60,
            "created_at": "2024-01-01T00:00:00",
            "updated_at": "2024-01-01T00:00:00",
            "is_template": true
        }
    ]
}
```

### 2. 获取个人计划列表
获取当前用户的所有个人计划。

**请求**
```
GET /api/plans/personal
```

**认证**: 需要登录

**响应示例**
```json
{
    "code": 200,
    "message": "获取个人计划成功",
    "data": [
        {
            "id": 2,
            "name": "我的训练计划",
            "description": "个人定制训练计划",
            "difficulty": "中级",
            "duration": 90,
            "created_at": "2024-01-01T00:00:00",
            "updated_at": "2024-01-01T00:00:00",
            "template_id": null,
            "is_template": false
        }
    ]
}
```

### 3. 获取计划详情
获取指定计划的详细信息，包括所有动作和组数据。

**请求**
```
GET /api/plans/{plan_id}
```

**参数**
- `plan_id`: 计划ID

**认证**: 查看个人计划需要登录，查看模板计划不需要

**响应示例**
```json
{
    "code": 200,
    "message": "获取计划详情成功",
    "data": {
        "id": 1,
        "name": "新手入门计划",
        "description": "适合健身新手的基础训练计划",
        "difficulty": "初级",
        "duration": 60,
        "user_id": null,
        "is_template": true,
        "template_id": null,
        "created_at": "2024-01-01T00:00:00",
        "updated_at": "2024-01-01T00:00:00",
        "actions": [
            {
                "action_id": 1,
                "order": 1,
                "sets_count": 3,
                "rest": 60,
                "weight": 360.0,
                "note": "",
                "record_bilateral": false,
                "action_info": {
                    "id": 1,
                    "name": "深蹲",
                    "name_en": "Squat",
                    "gifUrl": "squat.gif",
                    "description": "基础下肢训练动作",
                    "bodypart_id": 1,
                    "equipment_id": 1,
                    "is_bilateral": false
                },
                "sets": [
                    {
                        "id": 1,
                        "set_number": 1,
                        "weight": 20.0,
                        "reps": 12,
                        "left_weight": null,
                        "right_weight": null,
                        "created_at": "2024-01-01T00:00:00"
                    },
                    {
                        "id": 2,
                        "set_number": 2,
                        "weight": 20.0,
                        "reps": 10,
                        "left_weight": null,
                        "right_weight": null,
                        "created_at": "2024-01-01T00:00:00"
                    },
                    {
                        "id": 3,
                        "set_number": 3,
                        "weight": 20.0,
                        "reps": 8,
                        "left_weight": null,
                        "right_weight": null,
                        "created_at": "2024-01-01T00:00:00"
                    }
                ]
            }
        ]
    }
}
```

### 4. 创建新计划
创建一个新的个人训练计划。

**请求**
```
POST /api/plans/create
```

**认证**: 需要登录

**请求体示例**
```json
{
    "name": "我的训练计划",
    "description": "个人定制的训练计划",
    "difficulty": "中级",
    "duration": 90,
    "actions": [
        {
            "action_id": 1,
            "rest": 60,
            "note": "注意动作标准",
            "record_bilateral": false,
            "sets": [
                {
                    "weight": 20.0,
                    "reps": 12
                },
                {
                    "weight": 22.5,
                    "reps": 10
                },
                {
                    "weight": 25.0,
                    "reps": 8
                }
            ]
        },
        {
            "action_id": 2,
            "rest": 90,
            "note": "",
            "record_bilateral": true,
            "sets": [
                {
                    "left_weight": 10.0,
                    "right_weight": 10.0,
                    "reps": 12
                },
                {
                    "left_weight": 12.5,
                    "right_weight": 12.5,
                    "reps": 10
                }
            ]
        }
    ]
}
```

**响应示例**
```json
{
    "code": 200,
    "message": "创建计划成功",
    "data": {
        "plan_id": 3
    }
}
```

### 5. 复制模板计划
从模板计划复制创建一个新的个人计划。

**请求**
```
POST /api/plans/copy/{template_id}
```

**参数**
- `template_id`: 模板计划ID

**认证**: 需要登录

**响应示例**
```json
{
    "code": 200,
    "message": "复制计划成功",
    "data": {
        "plan_id": 4
    }
}
```

### 6. 更新计划
更新现有的个人训练计划。

**请求**
```
PUT /api/plans/{plan_id}
```

**参数**
- `plan_id`: 计划ID

**认证**: 需要登录，且只能更新自己的计划

**请求体**: 与创建计划相同的格式

**响应示例**
```json
{
    "code": 200,
    "message": "更新计划成功",
    "data": {
        "success": true
    }
}
```

### 7. 删除计划
删除指定的个人训练计划。

**请求**
```
DELETE /api/plans/{plan_id}
```

**参数**
- `plan_id`: 计划ID

**认证**: 需要登录，且只能删除自己的计划

**响应示例**
```json
{
    "code": 200,
    "message": "删除计划成功",
    "data": {
        "success": true
    }
}
```

### 8. 检查计划是否可删除
检查指定计划是否可以删除（没有进行中的训练会话）。

**请求**
```
GET /api/plans/{plan_id}/can_delete
```

**参数**
- `plan_id`: 计划ID

**认证**: 需要登录

**响应示例**
```json
{
    "code": 200,
    "message": "检查成功",
    "data": {
        "can_delete": true,
        "message": "可以删除"
    }
}
```

## 错误码说明

| 错误码 | 说明 | 示例 |
|--------|------|------|
| 200 | 成功 | 操作成功完成 |
| 400 | 请求参数错误 | 计划名称不能为空 |
| 401 | 未登录 | 请先登录 |
| 403 | 无权限操作 | 无权限操作此计划 |
| 404 | 资源不存在 | 计划不存在 |
| 409 | 业务逻辑冲突 | 计划正在使用中，无法删除 |
| 500 | 服务器错误 | 服务器错误，请稍后重试 |

## 多语言支持
API支持中文和英文，通过请求头 `Accept-Language` 指定：
- `zh_CN`: 中文（默认）
- `en_US`: 英文

## 数据说明

### 双侧训练 (record_bilateral)
- 当 `record_bilateral` 为 `true` 时，使用 `left_weight` 和 `right_weight` 字段
- 当 `record_bilateral` 为 `false` 时，使用 `weight` 字段
- 容量计算：
  - 普通训练：`weight × reps`
  - 双侧训练：`(left_weight + right_weight) × reps`

### 动作顺序 (order)
- 动作按照 `order` 字段排序显示
- 创建计划时会自动分配连续的order值（1, 2, 3...）

### 计划类型
- 模板计划：`is_template = true`，`user_id = null`
- 个人计划：`is_template = false`，`user_id` 为创建者ID

## 使用示例

### 前端集成示例（Swift）
```swift
// 获取模板计划列表
func getTemplatePlans() {
    let url = URL(string: "http://localhost:6000/api/plans/templates")!
    var request = URLRequest(url: url)
    request.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        // 处理响应
    }.resume()
}

// 创建计划
func createPlan(planData: [String: Any]) {
    let url = URL(string: "http://localhost:6000/api/plans/create")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: planData)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        // 处理响应
    }.resume()
}
``` 