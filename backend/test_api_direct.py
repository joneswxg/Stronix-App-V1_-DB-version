#!/usr/bin/env python3
import sys
import os
sys.path.append('src')

from flask import Flask
from stronix.routes.PlanRoutes import plan_bp
from stronix.services.AuthService import AuthService

def test_plan_detail_route():
    """直接测试计划详情路由"""
    print("测试计划详情路由...")
    
    # 创建Flask应用
    app = Flask(__name__)
    app.register_blueprint(plan_bp)
    
    with app.test_client() as client:
        # 先登录获取token
        login_response = client.post('/api/auth/login', 
                                   json={'email': 'iostest@example.com', 'password': 'password123'})
        
        if login_response.status_code != 200:
            print(f"登录失败: {login_response.status_code}")
            return
        
        token = login_response.get_json()['token']
        print(f"登录成功，token: {token[:50]}...")
        
        # 测试获取计划详情
        headers = {'Authorization': f'Bearer {token}'}
        response = client.get('/api/plans/3', headers=headers)
        
        print(f"响应状态码: {response.status_code}")
        print(f"响应内容: {response.get_json()}")

if __name__ == "__main__":
    test_plan_detail_route() 