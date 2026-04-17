import Foundation

private struct ScreenshotRecord: Codable, Hashable {
    let id: UUID
    let filename: String
    let capturedAt: Date
    let appName: String
    let bundleIdentifier: String?
    let projectName: String?
    let windowTitle: String?
    let byteSize: Int
}

final class ScreenshotStorage {
    let rootDirectory: URL

    private let fileManager = FileManager.default
    private let dayFolderFormatter: DateFormatter
    private let fileNameFormatter: DateFormatter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootDirectory: URL? = nil) {
        let fallbackRoot: URL
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            fallbackRoot = appSupport.appendingPathComponent("Rewind/Screenshots", isDirectory: true)
        } else {
            let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            fallbackRoot = temporary.appendingPathComponent("Rewind/Screenshots", isDirectory: true)
        }

        self.rootDirectory = rootDirectory ?? fallbackRoot

        let dayFolderFormatter = DateFormatter()
        dayFolderFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFolderFormatter.dateFormat = "yyyy-MM-dd"
        self.dayFolderFormatter = dayFolderFormatter

        let fileNameFormatter = DateFormatter()
        fileNameFormatter.locale = Locale(identifier: "en_US_POSIX")
        fileNameFormatter.dateFormat = "HHmmss_SSS"
        self.fileNameFormatter = fileNameFormatter

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        self.decoder = decoder

        try? createRootDirectoryIfNeeded()
    }

    func loadAllScreenshots() -> [ScreenshotEntry] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let folders = (try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var entries: [ScreenshotEntry] = []

        for folder in folders {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            let records = (try? loadRecords(in: folder)) ?? []
            for record in records {
                let fileURL = folder.appendingPathComponent(record.filename, isDirectory: false)
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    continue
                }

                entries.append(
                    ScreenshotEntry(
                        id: record.id,
                        fileURL: fileURL,
                        capturedAt: record.capturedAt,
                        appName: record.appName,
                        bundleIdentifier: record.bundleIdentifier,
                        projectName: record.projectName,
                        windowTitle: record.windowTitle,
                        byteSize: record.byteSize
                    )
                )
            }
        }

        return entries.sorted { $0.capturedAt > $1.capturedAt }
    }

    func saveScreenshot(
        data: Data,
        capturedAt: Date,
        appName: String,
        bundleIdentifier: String?,
        projectName: String?,
        windowTitle: String?
    ) throws -> ScreenshotEntry {
        try createRootDirectoryIfNeeded()

        let folder = dayFolderURL(for: capturedAt)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let sanitizedAppName = sanitizeFileNamePart(appName)
        let baseName = "\(fileNameFormatter.string(from: capturedAt))_\(sanitizedAppName)"
        let fileURL = uniqueImageURL(in: folder, baseName: baseName)

        try data.write(to: fileURL, options: .atomic)

        let record = ScreenshotRecord(
            id: UUID(),
            filename: fileURL.lastPathComponent,
            capturedAt: capturedAt,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            projectName: projectName,
            windowTitle: windowTitle,
            byteSize: data.count
        )

        var records = try loadRecords(in: folder)
        records.append(record)
        try writeRecords(records, in: folder)

        return ScreenshotEntry(
            id: record.id,
            fileURL: fileURL,
            capturedAt: record.capturedAt,
            appName: record.appName,
            bundleIdentifier: record.bundleIdentifier,
            projectName: record.projectName,
            windowTitle: record.windowTitle,
            byteSize: record.byteSize
        )
    }

    private func createRootDirectoryIfNeeded() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func dayFolderURL(for date: Date) -> URL {
        let folderName = dayFolderFormatter.string(from: date)
        return rootDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    private func uniqueImageURL(in folder: URL, baseName: String) -> URL {
        var candidate = folder.appendingPathComponent(baseName, isDirectory: false).appendingPathExtension("jpg")
        var index = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let nextName = "\(baseName)_\(index)"
            candidate = folder.appendingPathComponent(nextName, isDirectory: false).appendingPathExtension("jpg")
            index += 1
        }

        return candidate
    }

    private func sanitizeFileNamePart(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let replaced = trimmed.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "-",
            options: .regularExpression
        )
        return replaced.isEmpty ? "app" : replaced
    }

    private func indexURL(for folder: URL) -> URL {
        folder.appendingPathComponent("index.json", isDirectory: false)
    }

    private func loadRecords(in folder: URL) throws -> [ScreenshotRecord] {
        let indexURL = indexURL(for: folder)

        if fileManager.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            return try decoder.decode([ScreenshotRecord].self, from: data)
        }

        // Fallback for folders created before an index existed.
        let imageFiles = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "jpg" || ext == "jpeg"
        }

        return imageFiles.map { imageURL in
            let createdAt = (try? imageURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let stem = imageURL.deletingPathExtension().lastPathComponent
            let appName = stem.components(separatedBy: "_").dropFirst().joined(separator: " ")

            return ScreenshotRecord(
                id: UUID(),
                filename: imageURL.lastPathComponent,
                capturedAt: createdAt,
                appName: appName.isEmpty ? "Unknown App" : appName,
                bundleIdentifier: nil,
                projectName: nil,
                windowTitle: nil,
                byteSize: (try? Data(contentsOf: imageURL).count) ?? 0
            )
        }
    }

    private func writeRecords(_ records: [ScreenshotRecord], in folder: URL) throws {
        let sorted = records.sorted { $0.capturedAt < $1.capturedAt }
        let data = try encoder.encode(sorted)
        try data.write(to: indexURL(for: folder), options: .atomic)
    }
}
