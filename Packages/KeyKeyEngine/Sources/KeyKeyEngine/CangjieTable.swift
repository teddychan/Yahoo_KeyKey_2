import Foundation

// Maps a Cangjie letter-sequence code (e.g. "ab") to the characters that share it.
// Line format: "<code>\t<char>", one mapping per line (matches Resources/cangjie.txt).
public struct CangjieTable {
    private var table: [String: [String]] = [:]

    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let code = String(parts[0])
            table[code, default: []].append(String(parts[1]))
        }
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func characters(forCode code: String) -> [String] { table[code] ?? [] }
    public func hasCode(_ code: String) -> Bool { table[code] != nil }

    /// Iterates every (code, characters) entry in insertion-independent order.
    public func forEachEntry(_ body: (String, [String]) -> Void) {
        for (code, chars) in table { body(code, chars) }
    }

    /// Returns characters whose code matches `pattern`. `*` matches one-or-more
    /// letters (a–z); other characters match literally. With no `*`, behaves like
    /// an exact `characters(forCode:)`. Results are ordered by matched code length
    /// then the table's character order for that code (deterministic).
    public func characters(matching pattern: String) -> [String] {
        guard pattern.contains("*") else { return characters(forCode: pattern) }
        let regex = "^" + pattern.split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "[a-z]+") + "$"
        guard let re = try? NSRegularExpression(pattern: regex) else { return [] }
        let matched = table.keys.filter {
            re.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
        }
        return matched.sorted { ($0.count, $0) < ($1.count, $1) }
            .flatMap { table[$0] ?? [] }
    }
}
