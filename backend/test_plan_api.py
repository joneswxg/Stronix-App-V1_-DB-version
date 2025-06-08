#!/usr/bin/env python3
"""
训练计划API测试脚本
用于测试计划相关的API接口功能
"""

import requests
import json
import sys

# 配置
BASE_URL = "http://127.0.0.1:6000"
API_BASE = f"{BASE_URL}/api"

class PlanAPITester:
    def __init__(self):
        self.session = requests.Session()
        self.user_id = None
        self.token = None
        
    def login(self, username="test2@example.com", password="password123"):
        """登录获取token"""
        print("🔐 正在登录...")
        
        login_data = {
            "email": username,
            "password": password
        }
        
        response = self.session.post(f"{API_BASE}/auth/login", json=login_data)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success') == True:
                self.user_id = result.get('user', {}).get('id')
                self.token = result.get('token')
                # 设置Authorization header
                self.session.headers.update({'Authorization': f'Bearer {self.token}'})
                print(f"✅ 登录成功，用户ID: {self.user_id}")
                return True
            else:
                print(f"❌ 登录失败: {result.get('message')}")
                return False
        else:
            print(f"❌ 登录请求失败: {response.status_code}")
            return False
    
    def test_get_template_plans(self):
        """测试获取模板计划列表"""
        print("\n📋 测试获取模板计划列表...")
        
        response = self.session.get(f"{API_BASE}/plans/templates")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 获取模板计划成功")
            print(f"   模板数量: {len(result.get('data', []))}")
            for plan in result.get('data', []):
                print(f"   - {plan.get('name')} (ID: {plan.get('id')})")
            return result.get('data', [])
        else:
            print(f"❌ 获取模板计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return []
    
    def test_get_user_plans(self):
        """测试获取个人计划列表"""
        print("\n👤 测试获取个人计划列表...")
        
        response = self.session.get(f"{API_BASE}/plans/personal")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 获取个人计划成功")
            print(f"   个人计划数量: {len(result.get('data', []))}")
            for plan in result.get('data', []):
                print(f"   - {plan.get('name')} (ID: {plan.get('id')})")
            return result.get('data', [])
        else:
            print(f"❌ 获取个人计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return []
    
    def test_create_plan(self):
        """测试创建计划"""
        print("\n➕ 测试创建计划...")
        
        plan_data = {
            "name": "测试训练计划",
            "description": "这是一个测试用的训练计划",
            "difficulty": "中级",
            "duration": 90,
            "actions": [
                {
                    "action_id": 1,
                    "rest": 60,
                    "note": "注意动作标准",
                    "record_bilateral": False,
                    "sets": [
                        {"weight": 20.0, "reps": 12},
                        {"weight": 22.5, "reps": 10},
                        {"weight": 25.0, "reps": 8}
                    ]
                },
                {
                    "action_id": 2,
                    "rest": 90,
                    "note": "控制节奏",
                    "record_bilateral": True,
                    "sets": [
                        {"left_weight": 10.0, "right_weight": 10.0, "reps": 12},
                        {"left_weight": 12.5, "right_weight": 12.5, "reps": 10}
                    ]
                }
            ]
        }
        
        response = self.session.post(f"{API_BASE}/plans/create", json=plan_data)
        
        if response.status_code == 200:
            result = response.json()
            plan_id = result.get('data', {}).get('plan_id')
            print(f"✅ 创建计划成功，计划ID: {plan_id}")
            return plan_id
        else:
            print(f"❌ 创建计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return None
    
    def test_get_plan_detail(self, plan_id):
        """测试获取计划详情"""
        print(f"\n🔍 测试获取计划详情 (ID: {plan_id})...")
        
        response = self.session.get(f"{API_BASE}/plans/{plan_id}")
        
        if response.status_code == 200:
            result = response.json()
            plan = result.get('data', {})
            print(f"✅ 获取计划详情成功")
            print(f"   计划名称: {plan.get('name')}")
            print(f"   动作数量: {len(plan.get('actions', []))}")
            
            # 显示动作详情
            for action in plan.get('actions', []):
                action_info = action.get('action_info', {})
                print(f"   - {action_info.get('name')} ({len(action.get('sets', []))}组)")
                print(f"     容量: {action.get('weight', 0)}")
                print(f"     双侧训练: {'是' if action.get('record_bilateral') else '否'}")
            
            return plan
        else:
            print(f"❌ 获取计划详情失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return None
    
    def test_copy_template_plan(self, template_id):
        """测试复制模板计划"""
        print(f"\n📋➡️👤 测试复制模板计划 (ID: {template_id})...")
        
        response = self.session.post(f"{API_BASE}/plans/copy/{template_id}")
        
        if response.status_code == 200:
            result = response.json()
            plan_id = result.get('data', {}).get('plan_id')
            print(f"✅ 复制模板计划成功，新计划ID: {plan_id}")
            return plan_id
        else:
            print(f"❌ 复制模板计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return None
    
    def test_update_plan(self, plan_id):
        """测试更新计划"""
        print(f"\n✏️ 测试更新计划 (ID: {plan_id})...")
        
        updated_plan_data = {
            "name": "更新后的测试计划",
            "description": "这是更新后的描述",
            "difficulty": "高级",
            "duration": 120,
            "actions": [
                {
                    "action_id": 1,
                    "rest": 90,
                    "note": "更新后的备注",
                    "record_bilateral": False,
                    "sets": [
                        {"weight": 30.0, "reps": 8},
                        {"weight": 32.5, "reps": 6},
                        {"weight": 35.0, "reps": 4}
                    ]
                }
            ]
        }
        
        response = self.session.put(f"{API_BASE}/plans/{plan_id}", json=updated_plan_data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 更新计划成功")
            return True
        else:
            print(f"❌ 更新计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return False
    
    def test_check_can_delete(self, plan_id):
        """测试检查计划是否可删除"""
        print(f"\n🗑️❓ 测试检查计划是否可删除 (ID: {plan_id})...")
        
        response = self.session.get(f"{API_BASE}/plans/{plan_id}/can_delete")
        
        if response.status_code == 200:
            result = response.json()
            data = result.get('data', {})
            can_delete = data.get('can_delete', False)
            message = data.get('message', '')
            print(f"✅ 检查成功: {'可以删除' if can_delete else '不可删除'}")
            print(f"   原因: {message}")
            return can_delete
        else:
            print(f"❌ 检查失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return False
    
    def test_delete_plan(self, plan_id):
        """测试删除计划"""
        print(f"\n🗑️ 测试删除计划 (ID: {plan_id})...")
        
        response = self.session.delete(f"{API_BASE}/plans/{plan_id}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 删除计划成功")
            return True
        else:
            print(f"❌ 删除计划失败: {response.status_code}")
            print(f"   响应: {response.text}")
            return False
    
    def run_all_tests(self):
        """运行所有测试"""
        print("🚀 开始运行训练计划API测试...")
        print("=" * 50)
        
        # 1. 登录
        if not self.login():
            print("❌ 登录失败，无法继续测试")
            return
        
        # 2. 获取模板计划
        template_plans = self.test_get_template_plans()
        
        # 3. 获取个人计划
        user_plans = self.test_get_user_plans()
        
        # 4. 创建新计划
        new_plan_id = self.test_create_plan()
        
        if new_plan_id:
            # 5. 获取新创建计划的详情
            self.test_get_plan_detail(new_plan_id)
            
            # 6. 更新计划
            self.test_update_plan(new_plan_id)
            
            # 7. 再次获取计划详情查看更新结果
            self.test_get_plan_detail(new_plan_id)
            
            # 8. 检查是否可删除
            can_delete = self.test_check_can_delete(new_plan_id)
            
            # 9. 删除计划
            if can_delete:
                self.test_delete_plan(new_plan_id)
        
        # 10. 如果有模板计划，测试复制功能
        if template_plans:
            template_id = template_plans[0]['id']
            copied_plan_id = self.test_copy_template_plan(template_id)
            
            if copied_plan_id:
                # 获取复制计划的详情
                self.test_get_plan_detail(copied_plan_id)
                
                # 删除复制的计划
                if self.test_check_can_delete(copied_plan_id):
                    self.test_delete_plan(copied_plan_id)
        
        print("\n" + "=" * 50)
        print("🎉 所有测试完成！")

def main():
    """主函数"""
    print("训练计划API测试工具")
    print("确保后端服务器正在运行在 http://127.0.0.1:6000")
    print()
    
    # 检查服务器是否可用
    try:
        response = requests.get(f"{BASE_URL}/api/action/actions")
        if response.status_code != 200:
            print("❌ 无法连接到后端服务器，请确保服务器正在运行")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("❌ 无法连接到后端服务器，请确保服务器正在运行")
        sys.exit(1)
    
    # 运行测试
    tester = PlanAPITester()
    tester.run_all_tests()

if __name__ == "__main__":
    main() 