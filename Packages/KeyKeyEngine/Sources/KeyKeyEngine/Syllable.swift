// One Bopomofo syllable: at most one phoneme per class.
// Render order is fixed: consonant, medial, vowel, tone.
public struct Syllable: Equatable {
    public var consonant: Character?   // ㄅ..ㄙ
    public var medial: Character?      // ㄧ ㄨ ㄩ
    public var vowel: Character?       // ㄚ..ㄦ
    public var tone: Character?        // ˊ ˇ ˋ ˙  ; nil == tone 1 (no mark)

    public init() {}

    public var isEmpty: Bool {
        consonant == nil && medial == nil && vowel == nil && tone == nil
    }

    public var bpmf: String {
        var out = ""
        if let consonant { out.append(consonant) }
        if let medial { out.append(medial) }
        if let vowel { out.append(vowel) }
        if let tone { out.append(tone) }
        return out
    }
}
