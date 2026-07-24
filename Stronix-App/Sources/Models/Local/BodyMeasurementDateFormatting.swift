import Foundation

struct BodyMeasurementDateFormatting {
    private static let utc = TimeZone(secondsFromGMT: 0)!

    static func localCalendarDay(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func listDate(_ date: Date) -> String {
        displayFormatter("yyyy.MM.dd HH:mm").string(from: date)
    }

    static func detailDate(_ date: Date) -> String {
        displayFormatter("yyyy年MM月dd日").string(from: date)
    }

    static func editorDate(_ date: Date) -> String {
        displayFormatter("yyyy.MM.dd").string(from: date)
    }

    static func chartLabel(_ date: Date) -> String {
        displayFormatter("MM/dd").string(from: date)
    }

    static func changeRangeDate(_ date: Date) -> String {
        displayFormatter("yy.MM.dd").string(from: date)
    }

    static func changeDateTime(_ date: Date) -> String {
        displayFormatter("yy.MM.dd HH:mm").string(from: date)
    }

    static func changeChartLabel(_ date: Date) -> String {
        displayFormatter("MM.dd").string(from: date)
    }

    static func storageString(from date: Date) -> String {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded(.down)
        let normalized = Date(timeIntervalSince1970: milliseconds / 1_000)
        return storageFormatter.string(from: normalized)
    }

    static func storageDate(from value: String) -> Date? {
        if let date = storageFormatter.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = utc
            formatter.dateFormat = format
            formatter.isLenient = false
            guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
                continue
            }
            return date
        }
        return nil
    }

    private static let storageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = utc
        return formatter
    }()

    private static func displayFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
