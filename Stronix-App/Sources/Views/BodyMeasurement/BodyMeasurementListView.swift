import SwiftUI

struct BodyMeasurementListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BodyMeasurementViewModel
    @State private var showingEditSheet = false
    @State private var selectedRecord: BodyMeasurement?
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: BodyMeasurement?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.measurements.isEmpty {
                    emptyStateView
                } else {
                    recordsList
                }
            }
            .navigationTitle("体测记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                        viewModel.showAddSheet()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let record = selectedRecord {
                EditMeasurementSheet(viewModel: viewModel, record: record)
            }
        }
        .alert("删除确认", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let record = recordToDelete {
                    Task {
                        await deleteMeasurement(record)
                    }
                }
            }
        } message: {
            Text("确定要删除这条体测记录吗？此操作无法撤销。")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无体测记录")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("点击右上角 + 号添加您的第一条体测记录")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
    
    private var recordsList: some View {
        List {
            ForEach(viewModel.measurements) { record in
                MeasurementRowView(
                    record: record,
                    onEdit: {
                        selectedRecord = record
                        showingEditSheet = true
                    },
                    onDelete: {
                        recordToDelete = record
                        showingDeleteAlert = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
    }
    
    private func deleteMeasurement(_ record: BodyMeasurement) async {
        let success = await viewModel.deleteMeasurement(record.id)
        if success {
            // 删除成功，数据已在ViewModel中更新
        }
        recordToDelete = nil
    }
}

// 体测记录行视图
struct MeasurementRowView: View {
    let record: BodyMeasurement
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 日期和操作按钮
            HStack {
                Text(formatDate(record.measurementTimestamp))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: onEdit) {
                        Text("编辑")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onDelete) {
                        Text("删除")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 体测数据网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                DataItem(title: "体重", value: record.weightKg, unit: "kg")
                DataItem(title: "身高", value: record.heightCm, unit: "cm")
                DataItem(title: "体脂率", value: record.bodyFatPercentage, unit: "%")
                DataItem(title: "骨骼肌量", value: record.skeletalMuscleMassKg, unit: "kg")
                DataItem(title: "内脏脂肪", value: Double(record.visceralFatLevel), unit: "Lv")
                DataItem(title: "BMI", value: record.bmi, unit: "")
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// 数据项组件
struct DataItem: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    BodyMeasurementListView(viewModel: BodyMeasurementViewModel())
} 