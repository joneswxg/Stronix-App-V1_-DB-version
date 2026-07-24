import Foundation
import SwiftUI

@MainActor
final class BodyMeasurementViewModel: ObservableObject, UserScopedStateResetting {
    @Published var measurements: [BodyMeasurement] = []
    @Published var selectedMetric: MetricType = .weight
    @Published var selectedDataPoint: BodyMeasurement?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddSheet = false
    
    private let bodyMeasurementService = LocalBodyMeasurementService.shared
    private var loadGeneration = 0
    private var loadTask: Task<Void, Never>?

    private var currentUserId: Int {
        CurrentUserContext.shared.currentUserID ?? 0
    }
    
    // MARK: - 计算属性
    
    /// 最新的体测记录
    var latestMeasurement: BodyMeasurement? {
        measurements.first
    }
    
    /// 当前显示的数据点（选中的或最新的）
    var displayDataPoint: BodyMeasurement? {
        selectedDataPoint ?? latestMeasurement
    }
    
    /// 获取图表数据
    var chartData: [BodyMeasurement] {
        return measurements.reversed() // 图表需要按时间正序显示
    }
    
    /// 获取Y轴范围
    func getYAxisDomain() -> ClosedRange<Double> {
        let values = measurements.map { selectedMetric.getValue(from: $0) }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }
        
        let padding = max(1.0, (maxValue - minValue) * 0.1)
        let lowerBound = max(0, minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    // MARK: - 数据加载
    
    /// 加载用户的体测数据
    func loadMeasurements() async {
        loadTask?.cancel()
        let generation = loadGeneration
        let ownerID = currentUserId
        guard ownerID > 0 else {
            clearData()
            errorMessage = "用户未登录"
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            errorMessage = nil
            defer {
                if generation == loadGeneration { isLoading = false }
            }
            do {
                let response = try await bodyMeasurementService.getUserMeasurements(
                    BodyMeasurementQuery(userId: ownerID, limit: 100)
                )
                guard !Task.isCancelled,
                      generation == loadGeneration,
                      ownerID == currentUserId else { return }
                measurements = response.measurements
                if selectedDataPoint == nil { selectedDataPoint = latestMeasurement }
            } catch is CancellationError {
                return
            } catch {
                guard generation == loadGeneration else { return }
                errorMessage = "查询失败，请稍后重试"
            }
        }
        loadTask = task
        await task.value
    }

    func resetUserScopedState() {
        clearData()
    }

    func clearData() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        measurements = []
        selectedDataPoint = nil
        isLoading = false
        errorMessage = nil
        showingAddSheet = false
    }
    
    /// 刷新数据
    func refreshData() async {
        await loadMeasurements()
    }
    
    // MARK: - 数据操作
    
    /// 添加新的体测记录
    func addMeasurement(_ request: CreateBodyMeasurementRequest) async -> Bool {
        do {
            let response = try await bodyMeasurementService.createMeasurement(request)
            print("成功创建体测记录，ID: \(response.measurementId ?? 0)")
            
            // 重新加载数据
            await loadMeasurements()
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            print("创建体测记录失败: \(error)")
            return false
        }
    }
    
    /// 删除体测记录
    func deleteMeasurement(_ measurementId: Int) async -> Bool {
        do {
            let response = try await bodyMeasurementService.deleteMeasurement(measurementId)
            if response.success {
                // 从本地数组中移除
                measurements.removeAll { $0.id == measurementId }
                
                // 如果删除的是当前选中的数据点，重置选择
                if selectedDataPoint?.id == measurementId {
                    selectedDataPoint = latestMeasurement
                }
            }
            return response.success
            
        } catch {
            errorMessage = error.localizedDescription
            print("删除体测记录失败: \(error)")
            return false
        }
    }
    
    // MARK: - UI交互
    
    /// 选择指标类型
    func selectMetric(_ metric: MetricType) {
        selectedMetric = metric
    }
    
    /// 选择数据点
    func selectDataPoint(_ measurement: BodyMeasurement) {
        selectedDataPoint = measurement
    }
    
    /// 处理图表点击
    func handleChartTap(at index: Int) {
        let reversedIndex = measurements.count - 1 - index
        if reversedIndex >= 0 && reversedIndex < measurements.count {
            selectedDataPoint = measurements[reversedIndex]
        }
    }
    
    /// 显示添加记录界面
    func showAddSheet() {
        showingAddSheet = true
    }
    
    /// 隐藏添加记录界面
    func hideAddSheet() {
        showingAddSheet = false
    }
    
    // MARK: - 格式化方法
    
    /// 格式化日期显示
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化数值显示
    func formatValue(_ value: Double, for metric: MetricType) -> String {
        return "\(String(format: "%.1f", value))\(metric.unit)"
    }
    
    /// 获取指标值
    func getValueForMetric(_ measurement: BodyMeasurement) -> Double {
        return selectedMetric.getValue(from: measurement)
    }
    
    // MARK: - 初始化
    
    init() {
        // 移除自动加载，让视图控制何时加载数据
    }
} 