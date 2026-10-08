import Foundation

struct AppleScriptError: Error, Sendable {
    let code: Int
    let message: String
    /// -1743 = the user hasn't allowed (or has denied) this app to control Music.
    var isNotAuthorized: Bool { code == -1743 }
}

/// Runs AppleScript on a private background queue so the UI never stutters while Music answers.
/// Scripts are compiled once and reused.
///
/// `@unchecked Sendable` tells Swift "trust me, this is thread-safe": everything mutable
/// is only ever touched from inside `queue`, which runs one job at a time.
final class AppleScriptRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.vincent.NotchMusic.applescript")
    private var compiled: [String: NSAppleScript] = [:]

    /// Runs `source` and converts the raw result with `transform` (which also runs on the background queue).
    /// Set `cache` to false for one-off scripts so they aren't kept in memory forever.
    func run<T: Sendable>(
        _ source: String,
        cache: Bool = true,
        transform: @escaping @Sendable (NSAppleEventDescriptor) -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let script = cache ? self.script(for: source) : NSAppleScript(source: source) else {
                    continuation.resume(throwing: AppleScriptError(code: 0, message: "Couldn't create script"))
                    return
                }
                var errorInfo: NSDictionary?
                let result = script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                    let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    continuation.resume(throwing: AppleScriptError(code: code, message: message))
                } else {
                    continuation.resume(returning: transform(result))
                }
            }
        }
    }

    /// Runs a script when you don't care about its result (e.g. "next track").
    func run(_ source: String, cache: Bool = true) async throws {
        try await run(source, cache: cache) { _ in () }
    }

    private func script(for source: String) -> NSAppleScript? {
        if let cached = compiled[source] { return cached }
        let script = NSAppleScript(source: source)
        compiled[source] = script
        return script
    }
}
