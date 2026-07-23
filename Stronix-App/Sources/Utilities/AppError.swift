import Foundation

enum AppError {
    case authenticationRequired
    case validationFailed
    case resourceNotFound
    case permissionDenied
    case conflict
    case databaseUnavailable
    case requestFailed

    var userMessage: String {
        switch self {
        case .authenticationRequired:
            return "请先登录后重试"
        case .validationFailed:
            return "提交的数据无效，请检查后重试"
        case .resourceNotFound:
            return "请求的数据不存在"
        case .permissionDenied:
            return "无权限执行此操作"
        case .conflict:
            return "当前操作暂时无法完成，请稍后重试"
        case .databaseUnavailable:
            return "数据暂时无法读取，请稍后重试"
        case .requestFailed:
            return "暂时无法完成请求，请稍后重试"
        }
    }

    static func map(_ error: Error) -> AppError {
        if error is DatabaseError {
            return .databaseUnavailable
        }

        if let historyError = error as? TrainingHistoryRepositoryError {
            switch historyError {
            case .invalidOwnerID:
                return .authenticationRequired
            case .invalidHistoryID, .invalidPage, .invalidPageSize, .invalidPlanID, .invalidDateRange:
                return .validationFailed
            case .notFoundOrUnauthorized:
                return .resourceNotFound
            }
        }

        guard let planError = error as? LocalPlanError else {
            return .requestFailed
        }

        switch planError {
        case .unauthorized:
            return .authenticationRequired
        case .planNameEmpty, .noActions, .invalidSetData:
            return .validationFailed
        case .planNotFound, .actionNotFound, .templateNotFound:
            return .resourceNotFound
        case .permissionDenied:
            return .permissionDenied
        case .planInUse:
            return .conflict
        case .serverError:
            return .requestFailed
        }
    }
}
