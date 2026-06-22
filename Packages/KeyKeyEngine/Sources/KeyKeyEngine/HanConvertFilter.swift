import Foundation

// Character-level Han conversion mapping table.
// Parses OpenCC-style lines: "<from>\t<to1> <to2> ..." or "<from> <to1> ...".
// Only the first target is kept (char-level; no phrase resolution).
// Lines that are empty or start with '#' are ignored.
public struct HanConvertTable {
    // Maps a single source character to its first target character.
    public let map: [Character: Character]

    public init(text: String) {
        var map: [Character: Character] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            // Source is everything before the first tab or space; targets follow.
            guard let sepIndex = line.firstIndex(where: { $0 == "\t" || $0 == " " }) else { continue }
            let from = line[line.startIndex..<sepIndex]
            let rest = line[line.index(after: sepIndex)...].trimmingCharacters(in: .whitespaces)
            guard from.count == 1, let source = from.first else { continue }
            guard let target = rest.first else { continue }
            if map[source] == nil {
                map[source] = target
            }
        }
        self.map = map
    }

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        self.init(text: text)
    }
}

// Pure, deterministic character-level Traditional <-> Simplified converter.
// Unmapped characters pass through unchanged. No engine/app coupling.
public struct HanConvertFilter {
    public enum Direction {
        case traditionalToSimplified
        case simplifiedToTraditional
    }

    public let direction: Direction
    private let table: HanConvertTable

    public init(direction: Direction, table: HanConvertTable) {
        self.direction = direction
        self.table = table
    }

    public func convert(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            out.append(table.map[ch] ?? ch)
        }
        return out
    }
}
