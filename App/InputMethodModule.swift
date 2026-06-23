import Cocoa

// One input method as a self-contained unit. The controller keeps a registry of
// these (Cangjie, Simplex today) and selects one by `modeSuffix`, so adding a
// method is a single addition to that registry plus an Info.plist input mode —
// no scattered switches.
struct InputMethodModule {
    // Matches the Info.plist mode-id suffix (…YahooKeyKey2.<modeSuffix>), e.g. "Cangjie".
    let modeSuffix: String
    // Human-readable name (e.g. "倉頡"); reserved for future menu/UI use.
    let displayName: String
    // Builds a fresh engine for this method. Closures capture the shared tables/ranks.
    let makeEngine: () -> InputEngine
    // Settings that apply ONLY to this method, shown in the menu while it is active.
    // Empty for Cangjie/Simplex today; the menu wires the insertion point for future methods.
    var methodMenuItems: () -> [NSMenuItem] = { [] }
}
