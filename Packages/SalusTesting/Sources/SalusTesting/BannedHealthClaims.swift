// Ported 1:1 from Android
// `core/testing/src/main/kotlin/com/alicansekban/salus/core/testing/BannedHealthClaims.kt`.
//
// This is the one file in the repository that is allowed to spell the banned vocabulary out, and
// the scan below is what makes that exemption safe: every other Swift source is read and checked
// against the list, this one is skipped by name.
//
// Two shapes differ from Kotlin, neither of them in what is enforced:
//
//   * Kotlin calls `assertTrue` from JUnit, which puts a test framework in a production source
//     set. Here the scan throws instead, so `SalusTesting` links no test framework and every test
//     framework in the tree — Swift Testing today, XCTest wherever it is still needed — can call
//     it with its own failure reporting.
//   * Kotlin's paths are module-relative because Gradle guarantees the working directory
//     (`BannedHealthClaims.kt:25-27`). SwiftPM guarantees no such thing across 24 packages, so the
//     roots are `URL`s the caller resolves from its own `#filePath`.

import Foundation

/// The one vocabulary no user-facing text in this app may use, and the scan that enforces it.
///
/// `MISSED` dose rows are never written, and a snoozed dose writes a `PENDING` row on its own, so
/// the denominator behind the weekly share is the doses that were *recorded* — not the doses a
/// schedule called for, and not even the doses the user deliberately logged. Someone who records
/// only the doses they take reads as 100% while having missed doses that were never written down.
/// Calling that "adherence" — or "uyum", or "compliance" — turns a fact about the records into a
/// claim about the person's treatment, and it is the kind of edit that looks like a harmless copy
/// improvement right up until it ships.
///
/// This lives in `SalusTesting` rather than in the package that first needed it because the rule
/// is not the trends screen's: the paywall makes the same claims to someone who has not paid yet,
/// where the wrong word is a store policy problem rather than a cosmetic one. A ban list copied
/// into a second file drifts, and the drift is invisible until someone ships the wrong word — so
/// there is exactly one list, here, and every package's guard reads it.
///
/// Ported from `BannedHealthClaims.kt:29-176`.
public enum BannedHealthClaims {
    /// Stems, all lowercase, matched as substrings (`BannedHealthClaims.kt:55-77`).
    ///
    /// The entries are prefixes rather than dictionary words because both languages move
    /// underneath a whole word. Turkish inflects by suffix and softens the final consonant, so
    /// "hedef aralık" becomes "hedef aralığı" — a spelling that shares no ending with the one it
    /// came from; English inflects too, and "adherence" and "adhering" only agree on their first
    /// five letters. A list of whole words is always one inflection from a hole.
    ///
    /// Each entry is the shortest prefix that cannot turn up innocently, which is a judgement
    /// made per language rather than once:
    ///
    /// - "planlan" is safe as a bare stem. Code and comments in this project are written in
    ///   English, so a Turkish stem can only ever match a localized string — and a string saying
    ///   "planlanan"/"planlanmış" is describing a schedule, which is the framing being banned.
    /// - "planned" alone is *not* safe, for the mirror reason: it reads naturally in an English
    ///   comment ("kept as planned"), so the entry keeps enough of its object — "planned dos" —
    ///   to still cover "planned dose" and "planned doses".
    /// - "compli" alone is not safe either, since "complication" is a word a health app may
    ///   legitimately need. The concept is covered by three precise stems instead.
    ///
    /// A false positive costs a reviewer one line of reading; a miss ships a medical claim.
    /// When the two are weighed, the stem wins.
    public static let stems: [String] = [
        // Turkish.
        "uyum",
        // One entry for "hedef aralık", its softened "hedef aralığı", and the folded
        // "hedef aralik" that a Turkish uppercase produces.
        "hedef aral",
        "planlan",

        // English.
        "adher",
        "complian",
        "complie",
        "comply",
        "planned dos",
        "target range",

        // What a Turkish keyboard's capital i (U+0130) folds to under a locale-independent
        // lowercasing: a plain i followed by a combining dot above, which the natural spellings do
        // not match. Written as escapes rather than as the characters themselves, so that no
        // editor or checkout filter can normalize the mark away and quietly reopen the hole.
        "compli\u{0307}an",
        "compli\u{0307}e"
    ]

    /// Written the way a Turkish keyboard or a `tr` locale uppercase would produce them
    /// (`BannedHealthClaims.kt:80-86`). The capital i is escaped for the same reason the folded
    /// stems are.
    public static let turkishUppercased: [String] = [
        "HEDEF ARALIK",
        "COMPL\u{0130}ANCE",
        "\u{0130}LAÇ UYUMU",
        "PLANLANAN DOZ",
        "ADHERENCE"
    ]

    /// One inflected form per stem, already lowercase (`BannedHealthClaims.kt:94-104`).
    ///
    /// "hedef aralığı" is the case that prompted the stems: the possessive softens the final `k`
    /// to a `ğ`, so it matches neither "hedef aralık" nor its folded twin.
    public static let inflectedForms: [String] = [
        "ilaç uyumuna bakıldığında",
        "hedef aralığı",
        "planlanmış dozlar",
        "adhering to the schedule",
        "compliant with the plan",
        "complies with the schedule",
        "comply with the regimen",
        "planned doses",
        "target ranges"
    ]

    /// Why a scan failed. Descriptive on purpose: the message is the whole value of the guard to
    /// whoever trips it.
    public enum ScanError: Error, Equatable, CustomStringConvertible {
        /// A scanned file names a banned stem.
        case bannedTerm(file: String, stem: String)
        /// No Swift source was reached at all, which would otherwise pass by doing no work.
        case nothingScanned(roots: [String])
        /// No String Catalog was reached at all, for the same reason and with the same danger.
        case noCatalogScanned(paths: [String])
        /// A root could not be walked.
        case unreadableRoot(String)

        public var description: String {
            switch self {
            case let .bannedTerm(file, stem):
                "\(file) must not contain \"\(stem)\": the dose share counts recorded doses, not "
                    + "scheduled ones, and naming it that way turns a fact about the records into "
                    + "a claim about the person's treatment."

            case let .nothingScanned(roots):
                "No Swift source was found under \(roots). A path typo would otherwise make this "
                    + "guard pass by scanning nothing at all."

            case let .noCatalogScanned(paths):
                "No .xcstrings catalog was found under \(paths). Catalogs arrive one feature at a "
                    + "time, so a wrong path reads as \"nothing banned\" rather than as \"nothing "
                    + "read\" — which is the failure this case exists to make loud."

            case let .unreadableRoot(root):
                "\(root) could not be walked, so the guard cannot say what it contains."
            }
        }
    }

    /// Checks that every Swift file under `roots`, apart from `exemptFileName`, names nothing on
    /// `stems` — and that at least one file was scanned (`BannedHealthClaims.kt:135-146`).
    ///
    /// Comments are guarded as well as copy, because that is the route the word actually travels:
    /// a comment explaining a mapping in terms of the wrong concept is what a later reader renames
    /// a string to match. Tests are guarded for the same reason.
    ///
    /// Hidden directories are not descended into. That is where `.build` and `.git` live — a
    /// SwiftPM checkout carries whole dependency source trees no rule of ours governs — and it is
    /// the same scope `.swiftlint.yml` excludes.
    ///
    /// - Parameters:
    ///   - roots: directories to walk, resolved by the caller.
    ///   - exemptFileName: the guard's own file name. A guard that explains the rule has to spell
    ///     the banned words out to do it, so it is the one file the scan skips; passing a name
    ///     that matches nothing is fine and simply scans everything.
    public static func assertSourcesNameNothingBanned(roots: [URL], exemptFileName: String) throws {
        var scanned = 0

        for root in roots {
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard let enumerator else { throw ScanError.unreadableRoot(root.path) }

            for case let url as URL in enumerator {
                guard url.pathExtension == swiftExtension, url.lastPathComponent != exemptFileName else { continue }
                try assertFileNamesNothingBanned(url)
                scanned += 1
            }
        }

        guard scanned > 0 else { throw ScanError.nothingScanned(roots: roots.map(\.path)) }
    }

    /// Checks that every String Catalog reached through `paths` names nothing on `stems` — and
    /// that at least one was reached (the twin of Android's
    /// `assertFilesNameNothingBanned`, `BannedHealthClaims.kt:110-124`).
    ///
    /// This is the scan that matters most, because a catalog holds the words a user actually
    /// reads, and `assertSourcesNameNothingBanned` above reads `.swift` files only — a catalog was
    /// invisible to it. The whole file is folded and searched, comments included: an `.xcstrings`
    /// `"comment"` is what a translator reads before choosing a word, so a comment framing a
    /// string as adherence is how the wrong word reaches the copy.
    ///
    /// A path is either a catalog to check or a directory to walk for catalogs. Android passes
    /// files, because Gradle gives a module exactly two `strings.xml`; here one repository-wide
    /// run over `Packages/` covers every feature's catalog the moment it is added, with no edit to
    /// the feature that added it. Both shapes are useful, and both count toward the same guard.
    ///
    /// Hidden directories are not descended into, which is what keeps `.build` out: SwiftPM copies
    /// each catalog into a resource bundle there, and a stale copy would be scanned as if it were
    /// source.
    public static func assertCatalogsNameNothingBanned(paths: [URL]) throws {
        var scanned = 0

        for path in paths {
            if path.pathExtension == catalogExtension {
                try assertFileNamesNothingBanned(path)
                scanned += 1
                continue
            }

            let enumerator = FileManager.default.enumerator(
                at: path,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard let enumerator else { throw ScanError.unreadableRoot(path.path) }

            for case let url as URL in enumerator where url.pathExtension == catalogExtension {
                try assertFileNamesNothingBanned(url)
                scanned += 1
            }
        }

        guard scanned > 0 else { throw ScanError.noCatalogScanned(paths: paths.map(\.path)) }
    }

    /// Reads one file and checks it against every stem.
    ///
    /// The text is folded with Swift's locale-independent `lowercased()`, which is the twin of
    /// Kotlin's `lowercase(Locale.ROOT)` (`BannedHealthClaims.kt:173`) and is not incidental.
    /// Turkish has two i's, so uppercasing a term and folding it back does not always return the
    /// term: "hedef aralık" becomes "HEDEF ARALIK" with a plain `I`, which folds to a *dotted* `i`
    /// — "hedef aralik", a string the natural spelling does not match. The list therefore carries
    /// the folded spellings next to the natural ones. Folding with the device locale would make
    /// the answer depend on where the build ran, and a guard that passes on CI and fails on a
    /// developer's laptop is not a guard.
    private static func assertFileNamesNothingBanned(_ url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8).lowercased()

        for stem in stems where text.contains(stem) {
            throw ScanError.bannedTerm(file: url.path, stem: stem)
        }
    }

    private static let swiftExtension = "swift"
    private static let catalogExtension = "xcstrings"
}
