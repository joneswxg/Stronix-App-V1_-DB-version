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

    private let operations: any BodyMeasurementOperating
    private var loadGeneration = 0
    private var loadTask: Task<Void, Never>?

    var latestMeasurement: BodyMeasurement? {
        measurements.first
    }

    var displayDataPoint: BodyMeasurement? {
        selectedDataPoint ?? latestMeasurement
    }

    var chartData: [BodyMeasurement] {
        measurements.reversed()
    }

    init(operations: any BodyMeasurementOperating = BodyMeasurementUseCases()) {
        self.operations = operations
    }

    func getYAxisDomain() -> ClosedRange<Double> {
        let values = measurements.map { selectedMetric.getValue(from: $0) }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }
        let padding = max(1.0, (maxValue - minValue) * 0.1)
        return max(0, minValue - padding)...maxValue + padding
    }

    func loadMeasurements() async {
        loadTask?.cancel()
        let generation = loadGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            errorMessage = nil
            defer {
                if generation == loadGeneration { isLoading = false }
            }
            do {
                let loadedMeasurements = try await operations.listMeasurements()
                guard !Task.isCancelled, generation == loadGeneration else { return }
                measurements = loadedMeasurements
                if selectedDataPoint == nil {
                    selectedDataPoint = latestMeasurement
                }
            } catch is CancellationError {
                return
            } catch {
                guard generation == loadGeneration else { return }
                errorMessage = message(for: error)
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

    func refreshData() async {
        await loadMeasurements()
    }

    func addMeasurement(_ draft: BodyMeasurementDraft) async -> Bool {
        do {
            let measurement = try await operations.createMeasurement(draft)
            measurements.append(measurement)
            sortMeasurements()
            selectedDataPoint = measurement
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async -> Bool {
        do {
            let measurement = try await operations.updateMeasurement(id: id, with: draft)
            guard let index = measurements.firstIndex(where: { $0.id == id }) else {
                await loadMeasurements()
                return true
            }
            measurements[index] = measurement
            sortMeasurements()
            if selectedDataPoint?.id == id {
                selectedDataPoint = measurement
            }
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func deleteMeasurement(_ measurementID: Int) async -> Bool {
        do {
            try await operations.deleteMeasurement(id: measurementID)
            measurements.removeAll { $0.id == measurementID }
            if selectedDataPoint?.id == measurementID {
                selectedDataPoint = latestMeasurement
            }
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func selectMetric(_ metric: MetricType) {
        selectedMetric = metric
    }

    func selectDataPoint(_ measurement: BodyMeasurement) {
        selectedDataPoint = measurement
    }

    func handleChartTap(at index: Int) {
        let reversedIndex = measurements.count - 1 - index
        if reversedIndex >= 0 && reversedIndex < measurements.count {
            selectedDataPoint = measurements[reversedIndex]
        }
    }

    func showAddSheet() {
        showingAddSheet = true
    }

    func hideAddSheet() {
        showingAddSheet = false
    }

    func formatDate(_ date: Date) -> String {
        BodyMeasurementDateFormatting.listDate(date)
    }

    func formatValue(_ value: Double, for metric: MetricType) -> String {
        "\(String(format: "%.1f", value))\(metric.unit)"
    }

    func getValueForMetric(_ measurement: BodyMeasurement) -> Double {
        selectedMetric.getValue(from: measurement)
    }

    private func sortMeasurements() {
        measurements.sort {
            if $0.measurementTimestamp != $1.measurementTimestamp {
                return $0.measurementTimestamp > $1.measurementTimestamp
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id > $1.id
        }
    }

    private func message(for error: Error) -> String {
        switch error as? BodyMeasurementRepositoryError {
        case .unauthenticated:
            return "用户未登录"
        case .notFoundOrUnauthorized:
            return "记录已不可用"
        case .invalidMeasurementID, .invalidMeasurementTimestamp, .invalidWeight, .invalidHeight, .invalidBodyFatPercentage,
             .invalidSkeletalMuscleMass, .invalidVisceralFatLevel:
            return "体测数据无效"
        case .malformedStoredTimestamp:
            return "记录日期无效"
        case nil:
            return "操作失败，请稍后重试"
        }
    }
}
