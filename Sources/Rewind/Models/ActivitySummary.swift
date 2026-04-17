import Foundation

enum SummaryWindow: String, CaseIterable, Identifiable {
    case day
    case week

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .day:
            return "Today"
        case .week:
            return "This Week"
        }
    }

    var reviewTitle: String {
        switch self {
        case .day:
            return "Today in Review"
        case .week:
            return "Week in Review"
        }
    }
}

struct ActivityContext: Hashable, Identifiable {
    let appName: String
    let projectName: String?

    var id: String {
        "\(appName)|\(projectName ?? "")"
    }

    var displayName: String {
        if let projectName, !projectName.isEmpty {
            return "\(appName) / \(projectName)"
        }
        return appName
    }

    var compactLabel: String {
        projectName ?? appName
    }

    var colorKey: String {
        if let projectName, !projectName.isEmpty {
            return "\(appName)|\(projectName)"
        }
        return appName
    }
}

struct ActivityContextCount: Identifiable {
    let context: ActivityContext
    let captureCount: Int

    var id: String {
        context.id
    }
}

struct TimelineSummary: Identifiable {
    let start: Date
    let end: Date
    let captureCount: Int
    let activeContextCount: Int
    let topContext: ActivityContext?

    var id: String {
        "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
    }
}

struct ActivityHeatmapRow: Identifiable {
    let context: ActivityContext
    let counts: [Int]

    var id: String {
        context.id
    }

    var totalCaptures: Int {
        counts.reduce(0, +)
    }
}

struct ActivitySummary {
    let window: SummaryWindow
    let periodStart: Date
    let periodEnd: Date
    let totalCaptures: Int
    let activeContextCount: Int
    let topContexts: [ActivityContextCount]
    let timeline: [TimelineSummary]
    let heatmapColumns: [String]
    let heatmapRows: [ActivityHeatmapRow]

    var isEmpty: Bool {
        totalCaptures == 0
    }

    var maxHeatValue: Int {
        max(heatmapRows.flatMap(\.counts).max() ?? 0, 1)
    }
}

extension ActivitySummary {
    static func build(
        from entries: [ScreenshotEntry],
        window: SummaryWindow,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ActivitySummary {
        let period = periodInterval(for: window, now: now, calendar: calendar)
        let periodEntries = entries.filter { entry in
            entry.capturedAt >= period.start && entry.capturedAt < period.end
        }

        let groupedByContext = Dictionary(grouping: periodEntries) { entry in
            activityContext(for: entry)
        }

        let topContexts = groupedByContext
            .map { ActivityContextCount(context: $0.key, captureCount: $0.value.count) }
            .sorted(by: sortContextCounts)

        let heatmapContexts = Array(topContexts.prefix(6)).map(\.context)
        let timeline = buildTimeline(
            entries: periodEntries,
            period: period,
            window: window,
            calendar: calendar
        )
        let (heatmapColumns, heatmapRows) = buildHeatmap(
            entries: periodEntries,
            contexts: heatmapContexts,
            period: period,
            window: window,
            calendar: calendar
        )

        return ActivitySummary(
            window: window,
            periodStart: period.start,
            periodEnd: period.end,
            totalCaptures: periodEntries.count,
            activeContextCount: groupedByContext.count,
            topContexts: topContexts,
            timeline: timeline,
            heatmapColumns: heatmapColumns,
            heatmapRows: heatmapRows
        )
    }

    private static func periodInterval(
        for window: SummaryWindow,
        now: Date,
        calendar: Calendar
    ) -> DateInterval {
        switch window {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .week:
            if let week = calendar.dateInterval(of: .weekOfYear, for: now) {
                return week
            }
            let dayStart = calendar.startOfDay(for: now)
            let fallbackStart = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart
            let fallbackEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            return DateInterval(start: fallbackStart, end: fallbackEnd)
        }
    }

    private static func activityContext(for entry: ScreenshotEntry) -> ActivityContext {
        let trimmedProject = entry.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ActivityContext(
            appName: entry.appName,
            projectName: trimmedProject?.isEmpty == true ? nil : trimmedProject
        )
    }

    private static func sortContextCounts(
        lhs: ActivityContextCount,
        rhs: ActivityContextCount
    ) -> Bool {
        if lhs.captureCount != rhs.captureCount {
            return lhs.captureCount > rhs.captureCount
        }
        return lhs.context.displayName.localizedCaseInsensitiveCompare(rhs.context.displayName) == .orderedAscending
    }

    private static func buildTimeline(
        entries: [ScreenshotEntry],
        period: DateInterval,
        window: SummaryWindow,
        calendar: Calendar
    ) -> [TimelineSummary] {
        let buckets: [(Date, Date)]
        switch window {
        case .day:
            buckets = makeBuckets(
                start: period.start,
                end: period.end,
                component: .hour,
                step: 3,
                calendar: calendar
            )
        case .week:
            buckets = makeBuckets(
                start: period.start,
                end: period.end,
                component: .day,
                step: 1,
                calendar: calendar
            )
        }

        return buckets.compactMap { start, end in
            let matching = entries.filter { entry in
                entry.capturedAt >= start && entry.capturedAt < end
            }

            guard !matching.isEmpty else {
                return nil
            }

            let grouped = Dictionary(grouping: matching) { entry in
                activityContext(for: entry)
            }

            let topContext = grouped
                .map { ActivityContextCount(context: $0.key, captureCount: $0.value.count) }
                .sorted(by: sortContextCounts)
                .first?
                .context

            return TimelineSummary(
                start: start,
                end: end,
                captureCount: matching.count,
                activeContextCount: grouped.count,
                topContext: topContext
            )
        }
        .sorted { $0.start > $1.start }
    }

    private static func makeBuckets(
        start: Date,
        end: Date,
        component: Calendar.Component,
        step: Int,
        calendar: Calendar
    ) -> [(Date, Date)] {
        var buckets: [(Date, Date)] = []
        var cursor = start

        while cursor < end {
            guard let next = calendar.date(byAdding: component, value: step, to: cursor) else {
                break
            }
            let bucketEnd = min(next, end)
            buckets.append((cursor, bucketEnd))
            cursor = bucketEnd
        }

        return buckets
    }

    private static func buildHeatmap(
        entries: [ScreenshotEntry],
        contexts: [ActivityContext],
        period: DateInterval,
        window: SummaryWindow,
        calendar: Calendar
    ) -> ([String], [ActivityHeatmapRow]) {
        switch window {
        case .day:
            let columns = (0..<24).map { String(format: "%02d", $0) }
            let rows = contexts.map { context in
                var counts = Array(repeating: 0, count: 24)
                for entry in entries where activityContext(for: entry) == context {
                    let hour = calendar.component(.hour, from: entry.capturedAt)
                    if counts.indices.contains(hour) {
                        counts[hour] += 1
                    }
                }
                return ActivityHeatmapRow(context: context, counts: counts)
            }
            return (columns, rows)
        case .week:
            let formatter = DateFormatter()
            formatter.locale = calendar.locale ?? Locale.current
            formatter.dateFormat = "EE"

            let columns = (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: period.start).map {
                    formatter.string(from: $0)
                }
            }

            let periodStart = calendar.startOfDay(for: period.start)
            let rows = contexts.map { context in
                var counts = Array(repeating: 0, count: 7)
                for entry in entries where activityContext(for: entry) == context {
                    let day = calendar.startOfDay(for: entry.capturedAt)
                    guard let offset = calendar.dateComponents([.day], from: periodStart, to: day).day else {
                        continue
                    }
                    if counts.indices.contains(offset) {
                        counts[offset] += 1
                    }
                }
                return ActivityHeatmapRow(context: context, counts: counts)
            }
            return (columns, rows)
        }
    }
}
