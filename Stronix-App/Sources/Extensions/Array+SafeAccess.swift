import Foundation

extension Array {
    /// 安全访问数组元素，避免越界崩溃
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 