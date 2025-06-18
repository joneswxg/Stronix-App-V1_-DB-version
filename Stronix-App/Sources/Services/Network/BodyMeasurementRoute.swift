import Foundation

class BodyMeasurementRoute: ObservableObject {
    private let baseURL = "http://localhost:6000/api"
    
    // MARK: - 获取用户体测记录
    
    /// 获取用户的体测记录
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - limit: 限制返回记录数量
    ///   - startDate: 开始日期 (可选)
    ///   - endDate: 结束日期 (可选)
    /// - Returns: 体测记录数组
    func getUserBodyMeasurements(userId: Int, limit: Int? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> [BodyMeasurementRecord] {
        var urlComponents = URLComponents(string: "\(baseURL)/body-measurements/\(userId)")!
        var queryItems: [URLQueryItem] = []
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw BodyMeasurementError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BodyMeasurementError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw BodyMeasurementError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let bodyMeasurementResponse = try decoder.decode(BodyMeasurementResponse.self, from: data)
            return bodyMeasurementResponse.measurements
            
        } catch let error as DecodingError {
            print("解码错误: \(error)")
            throw BodyMeasurementError.decodingError
        } catch {
            print("网络请求错误: \(error)")
            throw BodyMeasurementError.networkError
        }
    }
    
    // MARK: - 创建体测记录
    
    /// 创建新的体测记录
    /// - Parameter request: 创建体测记录的请求数据
    /// - Returns: 创建成功的记录ID
    func createBodyMeasurement(_ request: CreateBodyMeasurementRequest) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/body-measurements") else {
            throw BodyMeasurementError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BodyMeasurementError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw BodyMeasurementError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let createResponse = try decoder.decode(CreateBodyMeasurementResponse.self, from: data)
            return createResponse.measurement_id
            
        } catch let error as EncodingError {
            print("编码错误: \(error)")
            throw BodyMeasurementError.encodingError
        } catch let error as DecodingError {
            print("解码错误: \(error)")
            throw BodyMeasurementError.decodingError
        } catch {
            print("网络请求错误: \(error)")
            throw BodyMeasurementError.networkError
        }
    }
    
    // MARK: - 获取单条体测记录详情
    
    /// 获取单条体测记录的详情
    /// - Parameter measurementId: 体测记录ID
    /// - Returns: 体测记录详情
    func getBodyMeasurementDetail(measurementId: Int) async throws -> BodyMeasurementRecord {
        guard let url = URL(string: "\(baseURL)/body-measurements/detail/\(measurementId)") else {
            throw BodyMeasurementError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BodyMeasurementError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    throw BodyMeasurementError.recordNotFound
                }
                throw BodyMeasurementError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let detailResponse = try decoder.decode(BodyMeasurementDetailResponse.self, from: data)
            return detailResponse.measurement
            
        } catch let error as DecodingError {
            print("解码错误: \(error)")
            throw BodyMeasurementError.decodingError
        } catch {
            print("网络请求错误: \(error)")
            throw BodyMeasurementError.networkError
        }
    }
    
    // MARK: - 删除体测记录
    
    /// 删除体测记录
    /// - Parameter measurementId: 体测记录ID
    /// - Returns: 删除是否成功
    func deleteBodyMeasurement(measurementId: Int) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/body-measurements/\(measurementId)") else {
            throw BodyMeasurementError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BodyMeasurementError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 404 {
                throw BodyMeasurementError.recordNotFound
            } else {
                throw BodyMeasurementError.serverError(httpResponse.statusCode)
            }
            
        } catch {
            print("网络请求错误: \(error)")
            throw BodyMeasurementError.networkError
        }
    }
}

// MARK: - 错误类型定义

enum BodyMeasurementError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case serverError(Int)
    case decodingError
    case encodingError
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .networkError:
            return "网络连接错误"
        case .serverError(let code):
            return "服务器错误 (状态码: \(code))"
        case .decodingError:
            return "数据解析错误"
        case .encodingError:
            return "数据编码错误"
        case .recordNotFound:
            return "记录未找到"
        }
    }
} 