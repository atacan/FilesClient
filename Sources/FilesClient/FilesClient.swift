import Dependencies
import Foundation
import OSLog
import XCTestDynamicOverlay

private let logger = Logger(subsystem: "FilesClient", category: "file_operations")

public struct FilesClient {
    public var read: @Sendable (URL) async throws -> String
    public var temporaryDirectory: @Sendable () -> URL
    public var temporaryFileWithExtension: @Sendable (String) -> URL
    public var createDirectory: @Sendable (URL) throws -> Void
    public var applicationSupportDirectory: @Sendable () -> URL?
    public var download: @Sendable (URL, URL) async throws -> Void

    // function versions with named arguments of the above
    public func read(url: URL) async throws -> String {
        try await read(url)
    }
    public func temporaryFile(withExtension: String) -> URL {
        temporaryFileWithExtension(withExtension)
    }
}

extension FilesClient: DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.uuid) var uuid

        return Self(
            read: { try String(contentsOf: $0) },
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
            temporaryFileWithExtension: {
                URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(uuid().uuidString)
                    .appendingPathExtension($0)
            },
            createDirectory: { try createDirectoryIfNotExists(at: $0) },
            applicationSupportDirectory: { createApplicationSupportDirectoryIfNotExists() },
            download: { from, to in
                let session = URLSession.shared
                let task = session.downloadTask(with: from) { url, response, error in
                    if let error = error {
                        logger.error("Error downloading file: \(error)")
                    }
                    else if let url = url {
                        do {
                            try FileManager.default.moveItem(at: url, to: to)
                        }
                        catch {
                            logger.error("Error moving downloaded file: \(error)")
                        }
                    }
                }
                task.resume()
            }
        )
    }
}

extension DependencyValues {
    public var filesClient: FilesClient {
        get { self[FilesClient.self] }
        set { self[FilesClient.self] = newValue }
    }
}

func createDirectoryIfNotExists(at url: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
        logger.info("'\(url.path)' already exists")
    }
    else {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        logger.info("Created '\(url.path)'")
    }
}

func createApplicationSupportDirectoryIfNotExists() -> URL? {
    // Get the application support directory
    let fileManager = FileManager.default
    guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        logger.error("Unable to access application support directory")
        return nil
    }

    // Get the app name from the info dictionary
    guard let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String else {
        logger.error("Unable to get app name from info dictionary")
        return nil
    }

    // Define the path for the app folder
    let appFolder = appSupportDir.appendingPathComponent(appName)

    // Check if the app folder exists, if not create it
    if fileManager.fileExists(atPath: appFolder.path) {
        logger.info("'\(appName)' folder already exists")
        return appFolder
    }
    else {
        do {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
            logger.info("Created '\(appName)' folder")
            return appFolder
        }
        catch {
            logger.error("Error creating '\(appName)' folder: \(error)")
            return nil
        }
    }
}
