import Foundation
import Testing

/// The shipping sources, read back from the checkout the tests were compiled
/// from.
///
/// Two rules in this project are enforced by *reading the code* rather than by
/// exercising it — the one-gate rule (ADR-0002) and the design tokens
/// (ADR-0003). Both need the same thing: every Swift file in the app target and
/// the widget extension, and a way to assert that a token appears in one file
/// and nowhere else. Both had their own copy of it, so adding a third shipping
/// target meant remembering to edit two suites.
enum ShippingSources {
    /// Every Swift file that ships: the app target and the widget extension.
    static func all() throws -> [String] {
        try ["Lightmeter", "LightmeterWidgets"].flatMap { target -> [String] in
            let directory = repositoryRoot.appending(path: target, directoryHint: .isDirectory)
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            )
            let contents = try #require(enumerator, "no sources at \(directory.path)")

            return contents
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" }
                .map(\.path)
        }
    }

    /// Asserts no shipping source outside `exception` contains any of `tokens`.
    ///
    /// `exception` is a *repository-relative path*, not a file name, so a second
    /// file of the same name somewhere else cannot exempt itself.
    static func expectAbsent(
        _ tokens: [String],
        exceptIn exception: String? = nil,
        reason: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let sources = try all()
        // Sanity: an empty sweep would pass this vacuously…
        #expect(sources.count > 20, sourceLocation: sourceLocation)
        // …and so would one that somehow missed the exempt file itself.
        if let exception {
            #expect(
                sources.contains { $0.hasSuffix(exception) },
                "the sweep missed \(exception) itself",
                sourceLocation: sourceLocation
            )
        }

        for path in sources where exception.map({ path.hasSuffix($0) }) != true {
            let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            for token in tokens {
                #expect(
                    text.contains(token) == false,
                    "\(path) names \(token) itself — \(reason)",
                    sourceLocation: sourceLocation
                )
            }
        }
    }

    /// The checkout the tests were built from — found from this file's own
    /// compile-time path.
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // LightmeterTests
            .deletingLastPathComponent()  // repository root
    }
}
