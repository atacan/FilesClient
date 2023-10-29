import Dependencies
import Foundation
import XCTestDynamicOverlay

public struct FilesClient {
    public var read: @Sendable (URL) async throws -> String
    public var temporaryDirectory: @Sendable () -> URL
    public var temporaryFileWithExtension: @Sendable (String) -> URL

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
