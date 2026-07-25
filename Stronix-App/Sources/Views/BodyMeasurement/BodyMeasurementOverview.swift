import SwiftUI
import Charts

struct BodyMeasurementOverview: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: BodyMeasurementViewModel
    let isAuthenticated: Bool
    let logout: () async -> Void
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xLarge) {
                    headerSection
                    content
                }
                .padding(.horizontal, DesignTokens.Spacing.large)
                .padding(.bottom, DesignTokens.Spacing.xxLarge)
            }
            .background(tokens.canvas)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                if isAuthenticated {
                    actionButtons
                        .padding(.horizontal, DesignTokens.Spacing.large)
                        .padding(.vertical, DesignTokens.Spacing.medium)
                        .background(tokens.canvas)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddMeasurementSheet(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isAuthenticated {
            signedOutState
        } else if viewModel.isLoading {
            loadingState
        } else if let errorMessage = viewModel.errorMessage {
            errorState(errorMessage)
        } else if viewModel.measurements.isEmpty {
            emptyState
        } else {
            metricCardsSection
            chartSection
        }
    }

    private var signedOutState: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundStyle(tokens.contentSecondary)
                .accessibilityHidden(true)

            Text("bodyMeasurement.state.signedOut.title")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(tokens.contentPrimary)

            Text("bodyMeasurement.state.signedOut.message")
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(tokens.contentSecondary)
                .multilineTextAlignment(.center)

            Button("bodyMeasurement.action.login") {
                showLogin = true
            }
            .font(DesignTokens.Typography.action)
            .foregroundStyle(tokens.onPrimary)
            .frame(minWidth: 120, minHeight: DesignTokens.Metric.minimumTapSize)
            .padding(.horizontal, DesignTokens.Spacing.large)
            .background(tokens.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxLarge)
    }

    private var loadingState: some View {
        ProgressView("bodyMeasurement.state.loading")
            .font(DesignTokens.Typography.body)
            .foregroundStyle(tokens.contentPrimary)
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityLabel("bodyMeasurement.state.loading")
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(tokens.error)
                .accessibilityHidden(true)

            Text("bodyMeasurement.error.title")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(tokens.contentPrimary)

            Text(message)
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(tokens.contentSecondary)
                .multilineTextAlignment(.center)

            Button("bodyMeasurement.action.retry") {
                Task { await viewModel.refreshData() }
            }
            .font(DesignTokens.Typography.action)
            .foregroundStyle(tokens.onPrimary)
            .frame(minHeight: DesignTokens.Metric.minimumTapSize)
            .padding(.horizontal, DesignTokens.Spacing.large)
            .background(tokens.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xLarge)
        .background(tokens.errorSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                .stroke(tokens.error, lineWidth: DesignTokens.Metric.borderWidth)
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(tokens.contentSecondary)
                .accessibilityHidden(true)

            Text("bodyMeasurement.state.empty.title")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(tokens.contentPrimary)

            Text("bodyMeasurement.state.empty.message")
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(tokens.contentSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxLarge)
    }

    private var headerSection: some View {
        HStack {
            Text("bodyMeasurement.title")
                .font(DesignTokens.Typography.pageTitle)
                .foregroundStyle(tokens.contentPrimary)
            Spacer()
            Button {
                if isAuthenticated {
                    Task { await logout() }
                } else {
                    showLogin = true
                }
            } label: {
                Image(systemName: isAuthenticated ? "person.circle.fill" : "person.circle")
                    .font(.title2)
                    .foregroundStyle(isAuthenticated ? tokens.primary : tokens.contentSecondary)
                    .frame(minWidth: DesignTokens.Metric.minimumTapSize, minHeight: DesignTokens.Metric.minimumTapSize)
            }
            .accessibilityLabel(isAuthenticated ? "bodyMeasurement.accessibility.logout" : "bodyMeasurement.accessibility.login")
        }
        .padding(.top, DesignTokens.Spacing.small)
    }

    private var metricCardsSection: some View {
        let displayData = viewModel.displayDataPoint

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                metricCards(displayData)
            }
            VStack(spacing: DesignTokens.Spacing.medium) {
                metricCards(displayData)
            }
        }
    }

    @ViewBuilder
    private func metricCards(_ displayData: BodyMeasurement?) -> some View {
        MetricCard(
            title: "bodyMeasurement.metric.weight",
            value: displayData?.weightKg ?? 0,
            unit: "kg",
            isSelected: viewModel.selectedMetric == .weight
        ) {
            viewModel.selectMetric(.weight)
        }

        MetricCard(
            title: "bodyMeasurement.metric.muscleMass",
            value: displayData?.skeletalMuscleMassKg ?? 0,
            unit: "kg",
            isSelected: viewModel.selectedMetric == .muscleMass
        ) {
            viewModel.selectMetric(.muscleMass)
        }

        MetricCard(
            title: "bodyMeasurement.metric.bodyFat",
            value: displayData?.bodyFatPercentage ?? 0,
            unit: "%",
            isSelected: viewModel.selectedMetric == .bodyFat
        ) {
            viewModel.selectMetric(.bodyFat)
        }
    }

    private var chartSection: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            selectedDataPointView
            chartView
        }
        .padding(.vertical, DesignTokens.Spacing.large)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                .stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth)
        }
        .shadow(color: tokens.shadow, radius: 5, x: 0, y: 2)
    }

    @ViewBuilder
    private var selectedDataPointView: some View {
        if let selectedData = viewModel.selectedDataPoint {
            HStack(alignment: .firstTextBaseline) {
                Text(BodyMeasurementDateFormatting.detailDate(selectedData.measurementTimestamp))
                    .font(DesignTokens.Typography.label)
                    .foregroundStyle(tokens.contentSecondary)
                Spacer()
                Text(viewModel.formatValue(viewModel.getValueForMetric(selectedData), for: viewModel.selectedMetric))
                    .font(DesignTokens.Typography.action)
                    .foregroundStyle(tokens.contentPrimary)
            }
            .padding(.horizontal, DesignTokens.Spacing.large)
        }
    }

    private var chartView: some View {
        let sortedChartData = viewModel.chartData.sorted { $0.measurementTimestamp < $1.measurementTimestamp }

        return Chart(Array(sortedChartData.enumerated()), id: \.offset) { index, data in
            LineMark(
                x: .value("Date", index),
                y: .value("Value", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(tokens.primary)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", index),
                y: .value("Value", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(tokens.primary)
            .symbolSize(50)

            if let selectedData = viewModel.selectedDataPoint,
               let selectedIndex = sortedChartData.firstIndex(where: { $0.id == selectedData.id }) {
                RuleMark(x: .value("Selected", selectedIndex))
                    .foregroundStyle(tokens.contentSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 240 : 200)
        .padding(.horizontal, DesignTokens.Spacing.large)
        .chartYScale(domain: viewModel.getYAxisDomain())
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(5, sortedChartData.count))) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), index < sortedChartData.count {
                        Text(BodyMeasurementDateFormatting.chartLabel(sortedChartData[index].measurementTimestamp))
                            .font(DesignTokens.Typography.feedback)
                            .foregroundStyle(tokens.contentSecondary)
                    }
                }
            }
        }
        .onTapGesture { location in
            handleChartTap(location: location, chartData: sortedChartData)
        }
        .onAppear {
            if let latestData = sortedChartData.last {
                viewModel.selectDataPoint(latestData)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("bodyMeasurement.accessibility.chartSummary")
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityHint("bodyMeasurement.accessibility.chartHint")
        .accessibilityAdjustableAction { direction in
            adjustChartSelection(direction, chartData: sortedChartData)
        }
    }

    private var chartAccessibilityValue: String {
        guard let selectedData = viewModel.selectedDataPoint else { return "" }
        return AppStrings.formatted(
            "bodyMeasurement.accessibility.chartValue",
            BodyMeasurementDateFormatting.detailDate(selectedData.measurementTimestamp),
            viewModel.formatValue(viewModel.getValueForMetric(selectedData), for: viewModel.selectedMetric)
        )
    }

    private func adjustChartSelection(_ direction: AccessibilityAdjustmentDirection, chartData: [BodyMeasurement]) {
        guard let selectedData = viewModel.selectedDataPoint,
              let currentIndex = chartData.firstIndex(where: { $0.id == selectedData.id }) else { return }

        let nextIndex: Int
        switch direction {
        case .increment:
            nextIndex = min(currentIndex + 1, chartData.count - 1)
        case .decrement:
            nextIndex = max(currentIndex - 1, 0)
        @unknown default:
            return
        }
        viewModel.selectDataPoint(chartData[nextIndex])
    }

    private func handleChartTap(location: CGPoint, chartData: [BodyMeasurement]) {
        guard !chartData.isEmpty else { return }

        let chartWidth = UIScreen.main.bounds.width - 80
        let dataRange = max(1, chartData.count - 1)
        let pointWidth = chartWidth / Double(dataRange)
        let tappedIndex = Int(round(location.x / pointWidth))

        if tappedIndex >= 0 && tappedIndex < chartData.count {
            viewModel.selectDataPoint(chartData[tappedIndex])
        }
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                actionButtonsContent
            }
            VStack(spacing: DesignTokens.Spacing.small) {
                actionButtonsContent
            }
        }
    }

    @ViewBuilder
    private var actionButtonsContent: some View {
        if !viewModel.measurements.isEmpty {
            NavigationLink(destination: BodyMeasurementListView(viewModel: viewModel)) {
                Label("bodyMeasurement.action.viewRecords", systemImage: "list.bullet")
                    .font(DesignTokens.Typography.action)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metric.minimumTapSize)
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .background(tokens.controlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous)
                            .stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth)
                    }
            }
            .foregroundStyle(tokens.primary)
        }

        Button {
            viewModel.showAddSheet()
        } label: {
            Label("bodyMeasurement.action.add", systemImage: "plus")
                .font(DesignTokens.Typography.action)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metric.minimumTapSize)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .background(tokens.primary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
        }
        .foregroundStyle(tokens.onPrimary)
    }
}

struct MetricCard: View {
    @Environment(\.designTokens) private var tokens
    let title: LocalizedStringKey
    let value: Double
    let unit: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.small) {
                Text(title)
                    .font(DesignTokens.Typography.label)
                    .foregroundStyle(tokens.contentSecondary)
                    .multilineTextAlignment(.center)

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xSmall) {
                    Text(value, format: .number.precision(.fractionLength(1)))
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(tokens.contentPrimary)
                    Text(unit)
                        .font(DesignTokens.Typography.label)
                        .foregroundStyle(tokens.contentSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(DesignTokens.Spacing.medium)
            .background(isSelected ? tokens.controlSurface : tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .stroke(isSelected ? tokens.primary : tokens.border, lineWidth: isSelected ? 2 : DesignTokens.Metric.borderWidth)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(
            AppStrings.formatted(
                "bodyMeasurement.accessibility.metricValue",
                value.formatted(.number.precision(.fractionLength(1))),
                unit,
                AppStrings.text(isSelected ? "bodyMeasurement.accessibility.selected" : "bodyMeasurement.accessibility.unselected")
            )
        )
        .accessibilityHint("bodyMeasurement.accessibility.metricHint")
    }
}

#Preview {
    BodyMeasurementOverview(
        viewModel: BodyMeasurementViewModel(),
        isAuthenticated: false,
        logout: {}
    )
    .withAppTheme()
}
