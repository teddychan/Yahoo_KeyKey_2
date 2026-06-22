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
}
