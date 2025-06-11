#!/usr/bin/env python3
"""
测试统计功能API的脚本
"""

import requests
import json

# API基础URL
BASE_URL = "http://127.0.0.1:6000"
API_BASE = f"{BASE_URL}/api"

class StatisticsAPITester:
    def __init__(self):
        self.session = requests.Session()
        self.user_id = None
        self.token = None
        
    def login(self, username="iostest@example.com", password="password123"):
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

    def test_statistics_api(self):
        """测试统计API"""
        print("🧪 开始测试统计功能API...")
        
        headers = {
            'Accept-Language': 'zh_CN'
        }
    
            # 测试1: 获取本周统计
        print("\n📊 测试1: 获取本周统计数据")
        try:
            response = self.session.get(f"{API_BASE}/training/statistics?time_range=week", headers=headers)
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            else:
                print(f"错误响应: {response.text}")
        except Exception as e:
            print(f"请求失败: {e}")
        
        # 测试2: 获取本月统计
        print("\n📊 测试2: 获取本月统计数据")
        try:
            response = self.session.get(f"{API_BASE}/training/statistics?time_range=month", headers=headers)
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            else:
                print(f"错误响应: {response.text}")
        except Exception as e:
            print(f"请求失败: {e}")
        
        # 测试3: 获取深蹲进步数据
        print("\n💪 测试3: 获取深蹲进步数据")
        try:
            response = self.session.get(f"{API_BASE}/training/action-progress?action_name=深蹲", headers=headers)
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            else:
                print(f"错误响应: {response.text}")
        except Exception as e:
            print(f"请求失败: {e}")
        
        # 测试4: 获取卧推进步数据
        print("\n💪 测试4: 获取卧推进步数据")
        try:
            response = self.session.get(f"{API_BASE}/training/action-progress?action_name=卧推", headers=headers)
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            else:
                print(f"错误响应: {response.text}")
        except Exception as e:
            print(f"请求失败: {e}")

    def test_without_auth(self):
        """测试无认证的情况"""
        print("\n🔒 测试5: 无认证访问（应该返回401）")
        try:
            # 创建一个新的session，不带认证
            response = requests.get(f"{API_BASE}/training/statistics")
            print(f"状态码: {response.status_code}")
            print(f"响应: {response.text}")
        except Exception as e:
            print(f"请求失败: {e}")

    def run_all_tests(self):
        """运行所有测试"""
        if not self.login():
            print("❌ 登录失败，无法继续测试")
            return
        
        self.test_statistics_api()
        self.test_without_auth()

def main():
    print("=" * 50)
    print("🏋️ Stronix 统计功能API测试")
    print("=" * 50)
    
    # 检查服务器是否运行
    try:
        response = requests.get(f"{BASE_URL}/")
        print("✅ 后端服务器正在运行")
    except:
        print("❌ 后端服务器未运行，请先启动服务器")
        exit(1)
    
    # 创建测试器并运行测试
    tester = StatisticsAPITester()
    tester.run_all_tests()
    
    print("\n✅ 测试完成！")

if __name__ == "__main__":
    main() 