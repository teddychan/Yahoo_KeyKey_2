// Minimal Gramambular-style grid + Viterbi walk over unigram log-probs.
public final class ReadingGrid {
    public struct Node {
        public let readingKey: String
        public let spanningLength: Int
        public var unigrams: [Unigram]
        public var overrideIndex: Int?
        // FIX 1: clamp index so an out-of-range overrideIndex never traps.
        // Nodes always have >=1 unigram by construction, so count - 1 >= 0.
        public var current: Unigram {
            let i = min(max(overrideIndex ?? 0, 0), unigrams.count - 1)
            return unigrams[i]
        }
    }

    private let readings: [String]
    // FIX 4: nodesByStart must be mutable so overrideCandidate can patch nodes.
    private var nodesByStart: [[Node]]   // nodesByStart[i] = nodes beginning at position i
    private static let maxSpan = 6
    private static let fallbackScore = -99.0
    // FIX 4: bonus that makes an overridden node always win the Viterbi walk.
    private static let overrideBonus = 1e9

    public init(readings: [String], languageModel lm: LanguageModel) {
        self.readings = readings
        self.nodesByStart = Array(repeating: [], count: readings.count)
        for i in 0..<readings.count {
            let maxLen = min(Self.maxSpan, readings.count - i)
            for len in 1...maxLen {
                let key = readings[i..<(i + len)].joined(separator: "-")
                let unigrams = lm.unigrams(forKey: key)
                if !unigrams.isEmpty {
                    nodesByStart[i].append(Node(readingKey: key, spanningLength: len,
                                                unigrams: unigrams, overrideIndex: nil))
                }
            }
            // guarantee a single-syllable node so the walk is total
            if !nodesByStart[i].contains(where: { $0.spanningLength == 1 }) {
                let r = readings[i]
                nodesByStart[i].insert(
                    Node(readingKey: r, spanningLength: 1,
                         unigrams: [Unigram(value: r, score: Self.fallbackScore)],
                         overrideIndex: nil),
                    at: 0)
            }
        }
    }

    // FIX 4: Force the candidate `value` at `position` by overriding the node that offers it.
    public func overrideCandidate(at position: Int, to value: String) {
        guard position >= 0 && position < nodesByStart.count else { return }
        for start in 0...position {
            for ni in nodesByStart[start].indices
                where position < start + nodesByStart[start][ni].spanningLength {
                if let idx = nodesByStart[start][ni].unigrams.firstIndex(where: { $0.value == value }) {
                    nodesByStart[start][ni].overrideIndex = idx
                    return
                }
            }
        }
    }

    // Viterbi over the DAG; returns the chosen nodes' current values.
    public func walk() -> [String] {
        let n = readings.count
        if n == 0 { return [] }
        var best = Array(repeating: -Double.infinity, count: n + 1)
        var fromIndex = Array(repeating: -1, count: n + 1)
        var fromNode = Array(repeating: -1, count: n + 1)
        best[0] = 0
        for i in 0..<n where best[i] > -.infinity {
            for (ni, node) in nodesByStart[i].enumerated() {
                let j = i + node.spanningLength
                // FIX 4: overridden nodes get a large bonus so they always win.
                let bonus = node.overrideIndex != nil ? Self.overrideBonus : 0
                let score = best[i] + node.current.score + bonus
                if score > best[j] { best[j] = score; fromIndex[j] = i; fromNode[j] = ni }
            }
        }
        var values: [String] = []
        var j = n
        // FIX 3: guard against an unreachable position (invariant holds today via
        // the fallback node, but explicit so a future refactor can't trap).
        while j > 0 {
            let i = fromIndex[j]
            guard i >= 0 else { break }
            values.append(nodesByStart[i][fromNode[j]].current.value)
            j = i
        }
        return values.reversed()
    }

    // FIX 2: guard out-of-range position — return empty rather than trapping.
    // Candidates overlapping a reading position, longer spans first, then file order.
    public func candidates(at position: Int) -> [String] {
        guard position >= 0 && position < nodesByStart.count else { return [] }
        var spanned: [(span: Int, values: [String])] = []
        for start in 0...position {
            for node in nodesByStart[start]
                where position < start + node.spanningLength {
                spanned.append((node.spanningLength, node.unigrams.map(\.value)))
            }
        }
        spanned.sort { $0.span > $1.span }   // longest phrases first
        return spanned.flatMap(\.values)
    }
}
