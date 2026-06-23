# KeyKey Sparkle Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the direct-download `YahooKeyKey2.app` (an InputMethodKit agent) update itself via Sparkle 2, with an EdDSA-signed appcast published at `https://www.dragonapp.com/keykey/appcast.xml` and a fully local release flow.

**Architecture:** The hand-rolled `swiftc` build vendors a pinned `Sparkle.framework`, embeds it under `Contents/Frameworks/`, and signs it inside-out. A small `Updater` singleton starts `SPUStandardUpdaterController` at launch (config read from Info.plist); the input menu gains a "檢查更新…" item. `tools/package-release.sh` EdDSA-signs each release `.zip` and regenerates the appcast, which is committed to the website repo.

**Tech Stack:** Swift + InputMethodKit/AppKit, Sparkle 2 (`sparkle-project/Sparkle`), bash, `codesign`/`notarytool`, GitHub Pages (the appcast host).

**Reference:** `~/git/yahoo-keykey-2/docs/superpowers/specs/2026-06-23-keykey-sparkle-autoupdate-design.md`. The signing/appcast pattern mirrors ClipMenu's `release.yml` and `docs/appcast.xml` in the `www.dragonapp.com` repo.

---

## File Structure

**`yahoo-keykey-2` repo:**
- Create `tools/fetch-sparkle.sh` — download + checksum-verify + extract a pinned `Sparkle.framework` and Sparkle's `bin/` tools into a gitignored cache.
- Create `tools/update-appcast.sh` — EdDSA-sign a release `.zip` and (re)generate `appcast.xml`.
- Create `App/Updater.swift` — Sparkle controller singleton.
- Create `docs/RELEASE.md` — one-time key setup + release runbook.
- Modify `tools/build-app.sh` — embed/link/sign Sparkle.
- Modify `tools/package-release.sh` — call `update-appcast.sh` after notarization.
- Modify `App/main.swift` — start the updater.
- Modify `App/InputController.swift` — add the "檢查更新…" menu item.
- Modify `App/Info.plist` — Sparkle keys + version bump.
- Modify `.gitignore` — ignore the Sparkle cache.

**`www.dragonapp.com` repo:**
- Create `docs/keykey/appcast.xml` — the generated feed (added at first release).

---

## Task 1: Vendor Sparkle (fetch script + gitignore)

**Files:**
- Create: `tools/fetch-sparkle.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Write `tools/fetch-sparkle.sh`**

```bash
#!/bin/bash
# Download a pinned Sparkle 2 release, verify its checksum, and extract
# Sparkle.framework + Sparkle's bin/ tools into a gitignored cache.
# Idempotent: re-running with the cache present is a no-op.
#
# Requires: curl, shasum, tar (with xz support). Produces:
#   build/sparkle/Sparkle.framework
#   build/sparkle/bin/{sign_update,generate_keys,generate_appcast}
set -euo pipefail

SPARKLE_VERSION="2.9.0"
SPARKLE_SHA256="PASTE_AFTER_STEP_2"   # pinned in Step 2 below

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/build/sparkle"
TARBALL="$CACHE/Sparkle-$SPARKLE_VERSION.tar.xz"
URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"

if [ -d "$CACHE/Sparkle.framework" ] && [ -x "$CACHE/bin/sign_update" ]; then
  echo "==> Sparkle $SPARKLE_VERSION already cached at $CACHE"
  exit 0
fi

mkdir -p "$CACHE"
echo "==> Downloading Sparkle $SPARKLE_VERSION"
curl -fSL "$URL" -o "$TARBALL"

echo "==> Verifying checksum"
ACTUAL="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
if [ "$SPARKLE_SHA256" = "PASTE_AFTER_STEP_2" ]; then
  echo "ERROR: SPARKLE_SHA256 is unset. Computed checksum is:"
  echo "  $ACTUAL"
  echo "Paste it into SPARKLE_SHA256 at the top of this script, then re-run." >&2
  exit 1
fi
if [ "$ACTUAL" != "$SPARKLE_SHA256" ]; then
  echo "ERROR: checksum mismatch: expected $SPARKLE_SHA256, got $ACTUAL" >&2
  exit 1
fi

echo "==> Extracting Sparkle.framework + bin/"
tar -xJf "$TARBALL" -C "$CACHE"
# The tarball lays out Sparkle.framework and bin/ at its root.
test -d "$CACHE/Sparkle.framework" || { echo "ERROR: Sparkle.framework not found after extract" >&2; exit 1; }
test -x "$CACHE/bin/sign_update"  || { echo "ERROR: bin/sign_update not found after extract" >&2; exit 1; }
echo "==> Done: $CACHE"
```

- [ ] **Step 2: Pin the checksum**

Run (downloads once and prints the computed checksum, then fails by design):
```bash
chmod +x tools/fetch-sparkle.sh && tools/fetch-sparkle.sh
```
Expected: it prints `ERROR: SPARKLE_SHA256 is unset.` followed by a 64-hex checksum. Copy that checksum into `SPARKLE_SHA256` at the top of `tools/fetch-sparkle.sh`, replacing `PASTE_AFTER_STEP_2`.

- [ ] **Step 3: Verify the fetch succeeds**

Run:
```bash
tools/fetch-sparkle.sh && ls build/sparkle/Sparkle.framework build/sparkle/bin/sign_update
```
Expected: PASS — both paths listed, no checksum error.

- [ ] **Step 4: Ignore the cache**

Add to `.gitignore`:
```
build/sparkle/
```

- [ ] **Step 5: Commit**

```bash
git add tools/fetch-sparkle.sh .gitignore
git commit -m "build: vendor pinned Sparkle 2 framework via fetch-sparkle.sh"
```

---

## Task 2: Generate EdDSA signing keys (one-time)

**Files:** none committed (private key stays in Keychain; public key captured for Task 4).

- [ ] **Step 1: Generate the keypair**

Run:
```bash
build/sparkle/bin/generate_keys
```
Expected: it stores a new private key in the login Keychain (item "Private key for signing Sparkle updates") and prints a `<key>SUPublicEDKey</key><string>…</string>` block (a base64 public key). If a key already exists it prints the existing public key instead — that is fine.

- [ ] **Step 2: Record the public key**

Copy the base64 string printed after `SUPublicEDKey`. You will paste it into `Info.plist` in Task 4. Keep it in this session; it is not secret.

- [ ] **Step 3: Sanity-check the private key is usable**

Run (signs an arbitrary file, proving the Keychain key works):
```bash
build/sparkle/bin/sign_update tools/fetch-sparkle.sh
```
Expected: prints `sparkle:edSignature="…" length="…"`. No commit for this task.

---

## Task 3: Embed, link, and sign Sparkle (build + release signing)

**Files:**
- Modify: `tools/build-app.sh`
- Modify: `tools/package-release.sh`

- [ ] **Step 1: Fetch Sparkle at the top of the build**

In `tools/build-app.sh`, immediately after the `set -euo pipefail` and the `ROOT=…` assignments (before "Cleaning previous build"), add:

```bash
SPARKLE_CACHE="$ROOT/build/sparkle"
echo "==> Ensuring Sparkle is vendored"
"$ROOT/tools/fetch-sparkle.sh"
```

- [ ] **Step 2: Link the app against Sparkle**

In the "Compiling App against KeyKeyEngine" `swiftc` invocation, add Sparkle to the search path, framework list, and rpath. Change the flags block to include:

```bash
  -F "$SPARKLE_CACHE" -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
```
(Place these alongside the existing `-framework InputMethodKit -framework Cocoa` flags.)

- [ ] **Step 3: Embed the framework before signing**

In `tools/build-app.sh`, after the "Copying localized strings (.lproj)" block and **before** the "Ad-hoc code-signing" block, add:

```bash
echo "==> Embedding Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_CACHE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
chmod -R u+w "$APP/Contents/Frameworks/Sparkle.framework"
```

- [ ] **Step 4: Sign Sparkle inside-out, then the app (no --deep)**

Replace the existing signing block:

```bash
echo "==> Ad-hoc code-signing the bundle (hardened runtime + explicit entitlements)"
codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" -s - "$APP"
codesign -dv "$APP"
```

with an **ad-hoc** inside-out signer (build-app.sh always signs ad-hoc — local and runnable; package-release.sh upgrades to Developer ID in Step 5 below):

```bash
echo "==> Code-signing Sparkle inside-out, then the app (ad-hoc)"
SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_V="$(/bin/ls -d "$SPARKLE_FW"/Versions/* | grep -v '/Current$' | head -1)"
for item in "$SPARKLE_V"/XPCServices/*.xpc "$SPARKLE_V/Autoupdate" "$SPARKLE_V/Updater.app"; do
  [ -e "$item" ] && codesign --force --options runtime -s - "$item"
done
codesign --force --options runtime -s - "$SPARKLE_FW"
# Sign the app last. No --deep: nested code (Sparkle) is already signed above.
codesign --force --options runtime --entitlements "$ENTITLEMENTS" -s - "$APP"
codesign -dv "$APP"
```

(build-app.sh deliberately does NOT read `DEVELOPER_ID_APP` or use `--timestamp`; ad-hoc signing needs neither, and Developer-ID re-signing happens in package-release.sh.)

- [ ] **Step 5: Replace `package-release.sh`'s `--deep` re-sign with inside-out Developer-ID signing**

`tools/package-release.sh` re-signs the app with Developer ID after building. Its current command (in the "3. Code signing" block) uses `--deep`, which would corrupt Sparkle's inside-out signature. Replace this exact command:

```bash
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_APP" "$APP"
```

with an inside-out Developer-ID signer (note `--timestamp`, required for notarization):

```bash
  SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
  SPARKLE_V="$(/bin/ls -d "$SPARKLE_FW"/Versions/* | grep -v '/Current$' | head -1)"
  for item in "$SPARKLE_V"/XPCServices/*.xpc "$SPARKLE_V/Autoupdate" "$SPARKLE_V/Updater.app"; do
    [ -e "$item" ] && codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$item"
  done
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$SPARKLE_FW"
  # Sign the app last; no --deep (Sparkle is already signed inside-out above).
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_APP" "$APP"
```

- [ ] **Step 6: Build and verify the embedded, signed framework**

Run:
```bash
tools/build-app.sh
codesign --verify --strict --verbose=2 build/YahooKeyKey2.app
test -d "build/YahooKeyKey2.app/Contents/Frameworks/Sparkle.framework" && echo "FRAMEWORK OK"
```
Expected: build completes; `--verify --strict` prints `valid on disk` / `satisfies its Designated Requirement`; prints `FRAMEWORK OK`.

- [ ] **Step 7: Commit**

```bash
git add tools/build-app.sh tools/package-release.sh
git commit -m "build: embed + inside-out sign Sparkle.framework (build + release)"
```

---

## Task 4: Add Sparkle keys to Info.plist

**Files:**
- Modify: `App/Info.plist`

- [ ] **Step 1: Add the Sparkle keys**

Inside the top-level `<dict>` of `App/Info.plist`, add (replace `PUBLIC_KEY_FROM_TASK_2` with the base64 string captured in Task 2, Step 2):

```xml
    <key>SUFeedURL</key><string>https://www.dragonapp.com/keykey/appcast.xml</string>
    <key>SUPublicEDKey</key><string>PUBLIC_KEY_FROM_TASK_2</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
```

- [ ] **Step 2: Validate the plist**

Run:
```bash
tools/build-app.sh >/dev/null
plutil -lint build/YahooKeyKey2.app/Contents/Info.plist
/usr/bin/plutil -extract SUPublicEDKey raw build/YahooKeyKey2.app/Contents/Info.plist
```
Expected: `OK` from `plutil -lint`; the public key string is printed (proves the key survived the `sed` in build-app.sh and is present).

- [ ] **Step 3: Commit**

```bash
git add App/Info.plist
git commit -m "feat: Sparkle Info.plist config (feed URL, public key, auto-checks)"
```

---

## Task 5: Updater singleton + launch wiring

**Files:**
- Create: `App/Updater.swift`
- Modify: `tools/build-app.sh` (add the new source file to the compile list)
- Modify: `App/main.swift`

- [ ] **Step 1: Write `App/Updater.swift`**

```swift
import Foundation
import Sparkle

/// Owns the Sparkle updater for the lifetime of the input-method process.
/// Sparkle reads SUFeedURL / SUPublicEDKey / SUEnableAutomaticChecks from
/// Info.plist, so this wrapper only starts the controller and exposes a
/// manual check for the input menu.
///
/// Guarded: if SUPublicEDKey is absent (e.g. an ad-hoc dev build that skipped
/// the key), the updater is not started — Sparkle requires the key and would
/// otherwise log errors on every launch.
final class Updater {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController?

    private init() {
        let hasKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.isEmpty == false
        guard hasKey else {
            controller = nil
            NSLog("YahooKeyKey: SUPublicEDKey missing; auto-update disabled")
            return
        }
        // startingUpdater: true begins scheduled checks using the Info.plist config.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Manual check, wired to the "檢查更新…" input-menu item.
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
```

- [ ] **Step 2: Add the source file to the build**

In `tools/build-app.sh`, append `"$APP_SRC"/Updater.swift` to the list of `.swift` files in the "Compiling App" `swiftc` invocation (the line that currently ends with `… "$APP_SRC"/AboutWindow.swift`).

- [ ] **Step 3: Start the updater at launch**

In `App/main.swift`, after the `server = IMKServer(name: connectionName, bundleIdentifier: bundleID)` line and its `nil` check, before `NSApplication.shared.run()`, add:

```swift
// Start Sparkle auto-update (no-op on builds without SUPublicEDKey).
_ = Updater.shared
```

- [ ] **Step 4: Build and verify it compiles + links Sparkle**

Run:
```bash
tools/build-app.sh
otool -L build/YahooKeyKey2.app/Contents/MacOS/YahooKeyKey2 | grep -i sparkle
```
Expected: build succeeds; `otool -L` shows `@rpath/Sparkle.framework/Versions/B/Sparkle` (proves the app links Sparkle).

- [ ] **Step 5: Commit**

```bash
git add App/Updater.swift App/main.swift tools/build-app.sh
git commit -m "feat: start Sparkle updater at launch via Updater singleton"
```

---

## Task 6: "檢查更新…" input-menu item

**Files:**
- Modify: `App/InputController.swift`

- [ ] **Step 1: Add the menu item**

In `App/InputController.swift`, in `menu()`, the "About" group currently reads:

```swift
        // 3. About (settings live as the toggles above; no separate Preferences window).
        menu.addItem(.separator())
        let about = NSMenuItem(title: "關於 Yahoo KeyKey 2…", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        return menu
```

Change it to add a "檢查更新…" item before About:

```swift
        // 3. Check for updates + About (stateless "open" actions).
        menu.addItem(.separator())
        let update = NSMenuItem(title: "檢查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        let about = NSMenuItem(title: "關於 Yahoo KeyKey 2…", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        return menu
```

- [ ] **Step 2: Add the action method**

In `App/InputController.swift`, next to `openAbout()`, add:

```swift
    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
```

- [ ] **Step 3: Build and verify**

Run:
```bash
tools/build-app.sh
```
Expected: build succeeds (the selector and `Updater.shared` resolve).

- [ ] **Step 4: Manual check (install + click the menu item)**

Run:
```bash
rm -rf ~/Library/Input\ Methods/YahooKeyKey2.app
cp -R build/YahooKeyKey2.app ~/Library/Input\ Methods/YahooKeyKey2.app
```
Then log out/in (or toggle the input source), switch to KeyKey, open its input menu, and click **檢查更新…**. Expected: Sparkle shows "checking…" then (with no live appcast yet) a "couldn't check for updates" dialog — acceptable here; it proves the menu item is wired. It reports correctly once the appcast is live (Tasks 8/10).

- [ ] **Step 5: Commit**

```bash
git add App/InputController.swift
git commit -m "feat: add 檢查更新… to the input menu"
```

---

## Task 7: Bump version to 1.3.0

**Files:**
- Modify: `App/Info.plist`

- [ ] **Step 1: Bump the version strings**

In `App/Info.plist`, set:
```xml
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
    <key>CFBundleVersion</key><string>5</string>
```
(`CFBundleVersion` was `4` in the v1.2.1 build; Sparkle compares this monotonic value.)

- [ ] **Step 2: Verify**

Run:
```bash
tools/build-app.sh >/dev/null
/usr/bin/plutil -extract CFBundleShortVersionString raw build/YahooKeyKey2.app/Contents/Info.plist
/usr/bin/plutil -extract CFBundleVersion raw build/YahooKeyKey2.app/Contents/Info.plist
```
Expected: prints `1.3.0` and `5`.

- [ ] **Step 3: Commit**

```bash
git add App/Info.plist
git commit -m "release: bump to 1.3.0 (first Sparkle-enabled build)"
```

---

## Task 8: Appcast generator + release hook

**Files:**
- Create: `tools/update-appcast.sh`
- Modify: `tools/package-release.sh`

- [ ] **Step 1: Write `tools/update-appcast.sh`**

```bash
#!/bin/bash
# EdDSA-sign a release .zip and (re)generate appcast.xml for KeyKey.
#
# Usage: tools/update-appcast.sh <path-to-zip> <version> <out-appcast.xml>
# Uses Sparkle's generate_appcast over the directory holding the zip, then
# points enclosure URLs at the GitHub release download.
set -euo pipefail

ZIP="${1:?usage: update-appcast.sh <zip> <version> <out.xml>}"
VERSION="${2:?missing version}"
OUT="${3:?missing output appcast path}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GENERATE_APPCAST="$ROOT/build/sparkle/bin/generate_appcast"
REPO="teddychan/yahoo-keykey-2"
DL_BASE="https://github.com/$REPO/releases/download"

test -x "$GENERATE_APPCAST" || { echo "ERROR: run tools/fetch-sparkle.sh first" >&2; exit 1; }
test -f "$ZIP" || { echo "ERROR: zip not found: $ZIP" >&2; exit 1; }

# generate_appcast reads the EdDSA private key from the Keychain and emits an
# appcast.xml next to the archives, with sparkle:edSignature + length filled in.
WORK="$(dirname "$ZIP")"
"$GENERATE_APPCAST" \
  --download-url-prefix "$DL_BASE/v$VERSION/" \
  --maximum-deltas 0 \
  -o "$OUT" \
  "$WORK"

# KeyKey declares no minimumSystemVersion / hardwareRequirements in the app
# Info.plist (they live only in the appcast), so inject them into each <item>
# if generate_appcast did not.
if ! grep -q "sparkle:minimumSystemVersion" "$OUT"; then
  /usr/bin/sed -i '' 's#</item>#    <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>\
    <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>\
</item>#' "$OUT"
fi

echo "==> Wrote appcast: $OUT"
echo "    Copy it to the website repo at docs/keykey/appcast.xml and commit."
```

- [ ] **Step 2: Make it executable + smoke-test against the current build zip**

Run:
```bash
chmod +x tools/update-appcast.sh
# Build an unsigned local zip just to exercise the generator:
ditto -c -k --keepParent build/YahooKeyKey2.app /tmp/kk-test.zip
tools/update-appcast.sh /tmp/kk-test.zip 1.3.0 /tmp/kk-appcast.xml
xmllint --noout /tmp/kk-appcast.xml && echo "XML WELL-FORMED"
grep -q 'sparkle:edSignature' /tmp/kk-appcast.xml && echo "HAS SIGNATURE"
grep -q 'minimumSystemVersion>12.0' /tmp/kk-appcast.xml && echo "HAS MINOS"
grep -q "releases/download/v1.3.0/" /tmp/kk-appcast.xml && echo "HAS DL URL"
```
Expected: prints `XML WELL-FORMED`, `HAS SIGNATURE`, `HAS MINOS`, `HAS DL URL`. (`xmllint` ships with macOS.)

- [ ] **Step 3: Hook it into the release script**

In `tools/package-release.sh`, in the "Summary" section (after the ZIP is created, before the final summary `echo`s), add:

```bash
# --- 5b. Sparkle appcast (only for signed release builds) -------------------
if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> Generating Sparkle appcast"
  APPCAST="$BUILD/appcast.xml"
  "$ROOT/tools/update-appcast.sh" "$ZIP" "$VERSION" "$APPCAST"
  echo "==> Appcast ready: $APPCAST (commit to www.dragonapp.com:docs/keykey/appcast.xml)"
else
  echo "==> Skipping appcast (ad-hoc build; Sparkle needs the Developer ID zip)"
fi
```

- [ ] **Step 4: Verify the script still parses**

Run:
```bash
bash -n tools/package-release.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`.

- [ ] **Step 5: Commit**

```bash
git add tools/update-appcast.sh tools/package-release.sh
git commit -m "release: EdDSA-sign zip + generate appcast.xml locally"
```

---

## Task 9: Release runbook

**Files:**
- Create: `docs/RELEASE.md`

- [ ] **Step 1: Write `docs/RELEASE.md`**

````markdown
# Releasing Yahoo KeyKey 2 (with Sparkle auto-update)

## One-time setup
1. `tools/fetch-sparkle.sh` — vendors Sparkle + its tools.
2. `build/sparkle/bin/generate_keys` — creates the EdDSA private key in your
   login Keychain and prints the public key. The public key is already pinned
   in `App/Info.plist` as `SUPublicEDKey`. The private key never leaves this Mac.

## Each release
1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `App/Info.plist`.
2. Build the signed + notarized release:
   ```sh
   export DEVELOPER_ID_APP="Developer ID Application: <name> (<TEAMID>)"
   export NOTARY_PROFILE="<notarytool-keychain-profile>"
   tools/package-release.sh
   ```
   This produces `build/YahooKeyKey2-<version>.{dmg,zip}` and `build/appcast.xml`.
3. Create the GitHub release at tag `v<version>` and upload BOTH the `.pkg`
   (run `tools/package-installer.sh`) and the `.zip`. Sparkle downloads the
   `.zip`; first-time users get the `.pkg`.
4. Copy `build/appcast.xml` into the website repo at `docs/keykey/appcast.xml`,
   commit, and push. GitHub Pages serves it at
   `https://www.dragonapp.com/keykey/appcast.xml` (the `SUFeedURL`).
5. Bump the Homebrew cask `Casks/yahoo-keykey-2.rb` (version + sha256 of the
   new `.dmg`) in `teddychan/homebrew-tap`.

## Notes
- KeyKey is an input method: after Sparkle installs an update, the new version
  takes effect when the input method restarts (toggle the input source or log
  out/in). This is expected.
- The first Sparkle build is v1.3.0; v1.2.1 users must update once manually.
````

- [ ] **Step 2: Commit**

```bash
git add docs/RELEASE.md
git commit -m "docs: Sparkle release runbook"
```

---

## Task 10: Publish the appcast to the website (at first release)

**Files (in the `www.dragonapp.com` repo):**
- Create: `docs/keykey/appcast.xml`

- [ ] **Step 1: Produce the real signed appcast**

After Task 8's release build with `DEVELOPER_ID_APP`/`NOTARY_PROFILE` set and the v1.3.0 GitHub release published (zip uploaded), `build/appcast.xml` contains the signed v1.3.0 item with the GitHub download URL.

- [ ] **Step 2: Add it to the site**

```bash
cp ~/git/yahoo-keykey-2/build/appcast.xml ~/git/www.dragonapp.com/docs/keykey/appcast.xml
cd ~/git/www.dragonapp.com
git switch -c keykey-appcast main
git add docs/keykey/appcast.xml
git commit -m "keykey: publish Sparkle appcast (v1.3.0)"
git push origin keykey-appcast:main
```

- [ ] **Step 3: Verify it is live and valid**

Run (after Pages rebuilds, ~1–2 min):
```bash
curl -s https://www.dragonapp.com/keykey/appcast.xml | xmllint --noout - && echo "LIVE + WELL-FORMED"
curl -s https://www.dragonapp.com/keykey/appcast.xml | grep -o 'releases/download/v1.3.0/[^"]*'
```
Expected: `LIVE + WELL-FORMED`; the v1.3.0 zip URL is printed.

---

## Task 11: End-to-end update verification (staged)

**Files:** none (verification only).

- [ ] **Step 1: Install the "old" version**

Build v1.3.0, install it to `~/Library/Input Methods/`, log out/in, and confirm KeyKey runs and typing works.

- [ ] **Step 2: Stage a newer build + local appcast**

Bump `App/Info.plist` to `1.3.1` / `CFBundleVersion 6` on a scratch branch, build a signed zip, and generate an appcast whose enclosure points at a **local** URL for that zip:
```bash
tools/update-appcast.sh build/YahooKeyKey2-1.3.1.zip 1.3.1 /tmp/local-appcast.xml
# Edit /tmp/local-appcast.xml: point the enclosure url at the locally served zip.
cp build/YahooKeyKey2-1.3.1.zip /tmp/
python3 -m http.server 8077 --directory /tmp &   # serve appcast + zip over http
```
Temporarily set `SUFeedURL` to `http://localhost:8077/local-appcast.xml` in the **installed** app's Info.plist for this test only.

- [ ] **Step 3: Trigger an update**

Open KeyKey's input menu → **檢查更新…**. Expected: Sparkle reports v1.3.1 available, downloads it, verifies the EdDSA signature, and installs it. Confirm `~/Library/Input Methods/YahooKeyKey2.app` Info.plist reads `1.3.1` (toggle the input source / re-login if the running version is cached).

- [ ] **Step 4: Confirm signature enforcement**

Hand-edit `/tmp/local-appcast.xml` to a wrong `sparkle:edSignature` and re-check. Expected: Sparkle refuses the update (signature verification fails). Restore the real appcast afterward.

- [ ] **Step 5: Record results**

No commit. Note any deviations (especially relaunch behaviour) in `docs/RELEASE.md` if they differ from the documented expectation.

---

## Notes for the implementer

- **Order matters:** Tasks 1→7 must precede a real signed release (Tasks 8/10). Task 11 can use staged/local artifacts before the public v1.3.0 ships.
- **Ad-hoc vs release:** local `tools/build-app.sh` signs everything ad-hoc (`-s -`); only `tools/package-release.sh` with `DEVELOPER_ID_APP` set produces a Gatekeeper-valid, notarizable bundle and a usable appcast. Sparkle will not install an ad-hoc-signed update on another machine.
- **Do not** commit anything under `build/` (gitignored) or the private key.
