// The iOS production `AiLanguageProvider` — the twin of Android's `ResourceAiLanguageProvider`,
// which resolves `ai_language_code` through the resource system.
//
// `FeatureAIHealth`'s `AiLanguageProvider` lives behind a protocol because `ResourceAiLanguageProvider`
// reads Android's resources; iOS reads its own `ai_language_code` string from `FeatureAIHealth`'s
// catalog, which is the exact same resource-resolved value by a different mechanism — the catalog
// key carries whatever qualifier the running app picked, so "the language the model answers in"
// follows the language the user is reading without any hand derivation from a locale.
//
// Lives here in the app target because the protocol's doc (see `AiLanguageProvider.swift`) places the
// production implementation there, where the composition root builds it and hands it to the module.

import FeatureAIHealth
import SalusAI

/// ``AiLanguageProvider`` resolved through `FeatureAIHealth`'s `ai_language_code` string, exactly as
/// Android's `ResourceAiLanguageProvider` resolves it through `values/strings.xml`. Any unrecognised
/// value falls back to Turkish (`ai_language_code`'s own documented default).
public struct ResourceAiLanguageProvider: AiLanguageProvider {
    public init() {}

    public func current() -> AiLanguage {
        switch AiHealthStrings.languageCode {
        case "en": .en
        default: .tr
        }
    }
}
