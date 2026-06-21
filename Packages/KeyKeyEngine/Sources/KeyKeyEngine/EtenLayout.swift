// ETen (倚天) Bopomofo layout. ASCII key -> phoneme component.
// Source of truth: McBopomofo Mandarin.cpp CreateETenLayout().
public struct EtenLayout: PhoneticLayout {
    public init() {}

    private static let consonants: [Character: Character] = [
        "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ",
        "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ",
        "v": "ㄍ", "k": "ㄎ", "h": "ㄏ",
        "g": "ㄐ", "7": "ㄑ", "c": "ㄒ",
        ",": "ㄓ", ".": "ㄔ", "/": "ㄕ", "j": "ㄖ",
        ";": "ㄗ", "'": "ㄘ", "s": "ㄙ",
    ]
    private static let medials: [Character: Character] = [
        "e": "ㄧ", "x": "ㄨ", "u": "ㄩ",
    ]
    private static let vowels: [Character: Character] = [
        "a": "ㄚ", "o": "ㄛ", "r": "ㄜ", "w": "ㄝ",
        "i": "ㄞ", "q": "ㄟ", "z": "ㄠ", "y": "ㄡ",
        "8": "ㄢ", "9": "ㄣ", "0": "ㄤ", "-": "ㄥ",
        "=": "ㄦ",
    ]
    // ETen tone keys: 2/3/4 as in Standard, but tone-5 (˙) is on "1" (no space key).
    private static let tones: [Character: Character?] = [
        "2": "ˊ", "3": "ˇ", "4": "ˋ", "1": "˙",
    ]

    public func component(for key: Character) -> Component? {
        if let c = EtenLayout.consonants[key] { return .consonant(c) }
        if let m = EtenLayout.medials[key] { return .medial(m) }
        if let v = EtenLayout.vowels[key] { return .vowel(v) }
        if let t = EtenLayout.tones[key] { return .tone(t) }
        return nil
    }
}
