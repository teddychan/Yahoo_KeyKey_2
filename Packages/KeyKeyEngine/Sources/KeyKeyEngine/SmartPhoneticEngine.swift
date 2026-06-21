// Orchestrates the reading buffer and the grid walk. The IMK controller talks only to this.
public final class SmartPhoneticEngine {
    private let lm: LanguageModel
    private let layout: PhoneticLayout
    private var buffer: ReadingBuffer
    private var readings: [String] = []
    // FIX 4: map reading position -> chosen VALUE (not candidate index).
    // This lets overrides survive even when a multi-syllable phrase wins the walk
    // and compresses the walked-segment array below readings.count.
    private var overrides: [Int: String] = [:]

    public init(languageModel: LanguageModel, layout: PhoneticLayout = StandardLayout()) {
        self.lm = languageModel
        self.layout = layout
        self.buffer = ReadingBuffer(layout: layout)
    }

    /// Returns true if the key was consumed by the engine.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        switch buffer.receive(key) {
        case .completed(let reading):
            readings.append(reading)
            return true
        case .updated, .empty:
            return true
        case .unhandled:
            return false
        }
    }

    public func backspace() {
        // if mid-syllable, edit the syllable; otherwise drop the last completed reading
        if case .empty = buffer.backspace(), !readings.isEmpty {
            readings.removeLast()
            // readings.count is now the index of the just-removed reading
            overrides.removeValue(forKey: readings.count)
        }
    }

    public func selectCandidate(_ index: Int) {
        let cands = candidates
        guard index >= 0, index < cands.count, !readings.isEmpty else { return }
        overrides[readings.count - 1] = cands[index]
    }

    // FIX 4: build the grid, apply value-keyed overrides via overrideCandidate, then re-walk.
    // This is the McBopomofo-style approach: override at the node level so the Viterbi
    // re-walk respects the selection even when a multi-syllable phrase would otherwise win.
    public var composingText: String {
        guard !readings.isEmpty else { return "" }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        for (pos, value) in overrides { grid.overrideCandidate(at: pos, to: value) }
        return grid.walk().joined()
    }

    public var candidates: [String] {
        guard !readings.isEmpty else { return [] }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        return grid.candidates(at: readings.count - 1)
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        readings = []; overrides = [:]; buffer = ReadingBuffer(layout: layout)
        return text
    }
}
