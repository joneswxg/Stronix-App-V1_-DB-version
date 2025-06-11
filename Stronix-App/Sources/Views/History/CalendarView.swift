import SwiftUI

// 日历日期结构体 - 避免使用Date对象的时区问题
struct CalendarDate: Hashable {
    let dateString: String  // YYYY-MM-DD格式
    let year: Int
    let month: Int
    let day: Int
    
    // 检查是否是今天
    var isToday: Bool {
        let today = Date()
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        return year == todayComponents.year && 
               month == todayComponents.month && 
               day == todayComponents.day
    }
    
    // 检查是否在指定月份
    func isInMonth(_ targetMonth: Int, year targetYear: Int) -> Bool {
        return year == targetYear && month == targetMonth
    }
}

// 模拟训练数据结构
struct TrainingDayData: Identifiable {
    let id = UUID()
    let date: Date
    let planNames: [String] // 训练计划名称
    let totalVolume: Int? // 总训练量

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    var dayOfMonth: String {
        TrainingDayData.dateFormatter.string(from: date)
    }
}

struct CalendarView: View {
    @State private var currentDate = Date()
    @State private var showingDetailView = false
    @State private var selectedDateString: String?
    @State private var trainingDatesInMonth: Set<String> = []
    @State private var isLoadingMonth = false
    @State private var sheetId = UUID() // 添加唯一标识符，确保Sheet能正确重新加载
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    // 加载当前月份的训练日期
    private func loadTrainingDatesForCurrentMonth() {
        Task {
            await MainActor.run {
                isLoadingMonth = true
            }
            
            do {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                guard let year = components.year, let month = components.month else { return }
                
                // 计算当月第一天和最后一天
                let startDate = String(format: "%04d-%02d-01", year, month)
                let daysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 31
                let endDate = String(format: "%04d-%02d-%02d", year, month, daysInMonth)
                
                print("🗓️ 加载月份训练日期: \(startDate) 到 \(endDate)")
                
                // 使用新的API获取训练日期
                let response = try await trainingHistoryService.getTrainingDates(
                    startDate: startDate,
                    endDate: endDate
                )
                
                // 转换为Set便于快速查找
                let trainingDates = Set(response.training_dates)
                
                await MainActor.run {
                    self.trainingDatesInMonth = trainingDates
                    self.isLoadingMonth = false
                    print("✅ 当月训练日期加载完成: \(trainingDates.sorted())")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMonth = false
                    print("❌ 加载当月训练日期失败: \(error)")
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            monthNavigationHeader
            weekdayHeader
            
            if isLoadingMonth {
                ProgressView("加载当月训练数据...")
                    .padding()
            }
            
            calendarGrid
            Spacer()
        }
        .onAppear {
            loadTrainingDatesForCurrentMonth()
        }
        .sheet(isPresented: $showingDetailView) {
            if let dateString = selectedDateString {
                HistoryListView(selectedDateString: dateString)
                    .id(sheetId) // 使用唯一ID确保每次都重新创建视图
            }
        }
    }
    
    // 月份导航头部
    private var monthNavigationHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            Spacer()
            Text(currentDate, formatter: DateFormatter.yearMonth)
                .font(.system(size: 24, weight: .bold))
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // 星期几标题
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 5)
    }
    
    // 日历网格
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(getDaysInMonth(date: currentDate), id: \.self) { calendarDate in
                CalendarDayCell(
                    calendarDate: calendarDate,
                    currentDate: currentDate,
                    hasTraining: trainingDatesInMonth.contains(calendarDate.dateString)
                ) {
                    print("📅 点击日期: \(calendarDate.dateString)")
                    
                    // 确保先重置状态，然后设置新值
                    showingDetailView = false
                    selectedDateString = nil
                    
                    // 使用异步延迟确保状态重置完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedDateString = calendarDate.dateString
                        sheetId = UUID() // 生成新的ID，确保Sheet重新加载
                        showingDetailView = true
                        print("📱 导航到日期详情: \(calendarDate.dateString)")
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // 月份切换方法
    private func previousMonth() {
        currentDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        loadTrainingDatesForCurrentMonth()
    }
    
    private func nextMonth() {
        currentDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        loadTrainingDatesForCurrentMonth()
    }
    
    // 将字符串转换为Date对象，使用UTC时区避免时区问题
    private func createDateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC时区
        
        let dateTimeString = "\(dateString) 12:00:00" // 使用中午时间避免边界问题
        
        return formatter.date(from: dateTimeString) ?? Date()
    }

    // 获取日历显示的所有日期 - 使用纯字符串方法避免时区问题
    private func getDaysInMonth(date: Date) -> [CalendarDate] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let currentComponents = calendar.dateComponents([.year, .month], from: date)
        guard let year = currentComponents.year, let month = currentComponents.month else {
            return []
        }
        
        // 获取当月第一天是星期几
        let firstDayString = String(format: "%04d-%02d-01", year, month)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        
        guard let firstDay = formatter.date(from: firstDayString) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let numberOfLeadingBlanks = (firstWeekday + 5) % 7
        
        // 获取当月天数
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count
        
        var days: [CalendarDate] = []
        
        // 添加上个月的尾部日期
        let prevMonth = month == 1 ? 12 : month - 1
        let prevYear = month == 1 ? year - 1 : year
        let prevMonthRange = calendar.range(of: .day, in: .month, for: formatter.date(from: String(format: "%04d-%02d-01", prevYear, prevMonth))!)!
        let daysInPrevMonth = prevMonthRange.count
        
        for i in 0..<numberOfLeadingBlanks {
            let day = daysInPrevMonth - numberOfLeadingBlanks + i + 1
            let dateString = String(format: "%04d-%02d-%02d", prevYear, prevMonth, day)
            days.append(CalendarDate(dateString: dateString, year: prevYear, month: prevMonth, day: day))
        }
        
        // 添加当月日期
        for day in 1...daysInMonth {
            let dateString = String(format: "%04d-%02d-%02d", year, month, day)
            days.append(CalendarDate(dateString: dateString, year: year, month: month, day: day))
        }
        
        // 添加下个月的开头日期，填满42个格子
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        let remainingDays = 42 - days.count
        
        for day in 1...remainingDays {
            let dateString = String(format: "%04d-%02d-%02d", nextYear, nextMonth, day)
            days.append(CalendarDate(dateString: dateString, year: nextYear, month: nextMonth, day: day))
        }
        
        return days
    }
}

// 日历单元格组件
struct CalendarDayCell: View {
    let calendarDate: CalendarDate
    let currentDate: Date
    let hasTraining: Bool
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 2) {
                dayNumberView
                trainingIndicatorView
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .background(Color.white)
            .border(Color.gray.opacity(0.2), width: 0.5)
            .onTapGesture(perform: onTap)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // 日期数字显示
    private var dayNumberView: some View {
        Text("\(calendarDate.day)")
            .font(.caption)
            .padding(4)
            .background(todayBackground)
            .cornerRadius(5)
            .foregroundColor(dayTextColor)
    }
    
    // 今天的背景色
    private var todayBackground: Color {
        calendarDate.isToday ? Color.blue.opacity(0.2) : Color.clear
    }
    
    // 日期文字颜色
    private var dayTextColor: Color {
        let currentComponents = Calendar.current.dateComponents([.year, .month], from: currentDate)
        let isCurrentMonth = calendarDate.isInMonth(currentComponents.month ?? 0, year: currentComponents.year ?? 0)
        return isCurrentMonth ? .black : .gray
    }
    
    // 训练标记显示
    @ViewBuilder
    private var trainingIndicatorView: some View {
        if hasTraining {
            // 蓝色打勾标记，表示当天有训练记录，居中显示
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// DateFormatter扩展
extension DateFormatter {
    static let yearMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
}

#Preview {
    CalendarView()
} 