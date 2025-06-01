//
//  DatabaseManager.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation

class DatabaseManager {
    // 单例模式，确保整个应用只有一个数据库管理实例
    static let shared = DatabaseManager()
    private init() {}
    
    // 使用DBConfig中的配置
    private let baseURL = DBConfig.baseURL
    
    // MARK: - 错误定义
    enum DatabaseError: Error {
        case invalidURL
        case invalidResponse
        case decodingError
        case networkError(Error)
    }
    
    // MARK: - 响应数据结构
    struct DatabaseResponse: Codable {
        let result: [[String: AnyCodable]]
        let metadata: Metadata
        
        struct Metadata: Codable {
            let rows_affected: Int
            let columns: [String]?
        }
    }
    
    // MARK: - 动作相关查询方法
    func fetchActions() async throws -> [ActionListView.Action] {
        let query = """
            SELECT 
                a.id,
                a.name,
                a.name_en,
                a.gifUrl as image_url,
                a.bodypart_id as body_part_id,
                a.equipment_id,
                GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
            LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
            GROUP BY a.id
        """
        
        return try await executeQuery(query, transform: { dict in
            ActionListView.Action(
                id: dict["id"] as! Int,
                name: dict["name"] as! String,
                name_en: dict["name_en"] as? String,
                image_url: dict["image_url"] as! String,
                body_part_id: dict["body_part_id"] as! Int,
                equipment_id: dict["equipment_id"] as! Int,
                target_muscle_ids: {
                    if let targetMuscleIdsString = dict["target_muscle_ids"] as? String {
                        return targetMuscleIdsString.split(separator: ",").map { Int($0)! }
                    } else {
                        return []
                    }
                }()
            )
        })
    }
    
    // MARK: - 目标肌肉相关查询方法
    func fetchTargetMuscles() async throws -> [ActionListView.TargetMuscle] {
        let query = "SELECT id, name, display_name FROM target_muscle"
        
        return try await executeQuery(query, transform: { dict in
            ActionListView.TargetMuscle(
                id: dict["id"] as! Int,
                name: dict["name"] as! String,
                display_name: dict["display_name"] as! String
            )
        })
    }
    
    // MARK: - 通用查询方法
    private func executeQuery<T>(_ query: String, transform: @escaping ([String: Any]) -> T) async throws -> [T] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/query?sql=\(encodedQuery)") else {
            throw DatabaseError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DatabaseError.invalidResponse
            }
            
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let result = jsonResponse?["result"] as? [[String: Any]] else {
                throw DatabaseError.decodingError
            }
            
            return result.map(transform)
        } catch {
            throw DatabaseError.networkError(error)
        }
    }
}

// MARK: - AnyCodable 辅助结构
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

