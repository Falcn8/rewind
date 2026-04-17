import Foundation
import Testing
@testable import Rewind

struct ActivitySummaryTests {
    @Test
    func dailySummaryGroupsByAppAndProject() throws {
        let calendar = fixedCalendar()
        let now = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 4,
            day: 17,
            hour: 12
        )))

        let entries = [
            makeEntry(
                appName: "Xcode",
                projectName: "Rewind",
                capturedAt: try #require(date(calendar: calendar, year: 2026, month: 4, day: 17, hour: 9, minute: 5))
            ),
            makeEntry(
                appName: "Xcode",
                projectName: "Rewind",
                capturedAt: try #require(date(calendar: calendar, year: 2026, month: 4, day: 17, hour: 9, minute: 55))
            ),
            makeEntry(
                appName: "Safari",
                projectName: "OpenAI Docs",
                capturedAt: try #require(date(calendar: calendar, year: 2026, month: 4, day: 17, hour: 14, minute: 20))
            ),
            makeEntry(
                appName: "Slack",
                projectName: nil,
                capturedAt: try #require(date(calendar: calendar, year: 2026, month: 4, day: 16, hour: 22, minute: 20))
            )
        ]

        let summary = ActivitySummary.build(
            from: entries,
            window: .day,
            now: now,
            calendar: calendar
        )

        #expect(summary.totalCaptures == 3)
        #expect(summary.activeContextCount == 2)
        #expect(summary.topContexts.first?.context.appName == "Xcode")
        #expect(summary.topContexts.first?.context.projectName == "Rewind")
        #expect(summary.topContexts.first?.captureCount == 2)

        let xcodeRow = try #require(summary.heatmapRows.first(where: { row in
            row.context.appName == "Xcode" && row.context.projectName == "Rewind"
        }))
        #expect(xcodeRow.counts[9] == 2)
        #expect(summary.timeline.contains(where: { $0.captureCount == 2 }))
    }

    @Test
    func weeklySummaryBuildsSevenDayHeatmap() throws {
        let calendar = fixedCalendar(firstWeekday: 2)
        let now = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            year: 2026,
            month: 4,
            day: 15,
            hour: 10
        )))

        let monday = try #require(date(calendar: calendar, year: 2026, month: 4, day: 13, hour: 11, minute: 0))
        let wednesday = try #require(date(calendar: calendar, year: 2026, month: 4, day: 15, hour: 15, minute: 30))
        let sundayPrior = try #require(date(calendar: calendar, year: 2026, month: 4, day: 12, hour: 9, minute: 0))

        let entries = [
            makeEntry(appName: "Xcode", projectName: "Rewind", capturedAt: monday),
            makeEntry(appName: "Xcode", projectName: "Rewind", capturedAt: wednesday),
            makeEntry(appName: "Slack", projectName: nil, capturedAt: sundayPrior)
        ]

        let summary = ActivitySummary.build(
            from: entries,
            window: .week,
            now: now,
            calendar: calendar
        )

        #expect(summary.totalCaptures == 2)
        #expect(summary.heatmapColumns.count == 7)
        #expect(summary.timeline.count >= 2)

        let xcodeRow = try #require(summary.heatmapRows.first(where: { row in
            row.context.appName == "Xcode" && row.context.projectName == "Rewind"
        }))

        #expect(xcodeRow.totalCaptures == 2)
        #expect(xcodeRow.counts.reduce(0, +) == 2)
    }

    private func fixedCalendar(firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(
        calendar: Calendar,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date? {
        calendar.date(from: DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
    }

    private func makeEntry(
        appName: String,
        projectName: String?,
        capturedAt: Date
    ) -> ScreenshotEntry {
        ScreenshotEntry(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg"),
            capturedAt: capturedAt,
            appName: appName,
            bundleIdentifier: nil,
            projectName: projectName,
            windowTitle: nil,
            byteSize: 24_000
        )
    }
}
