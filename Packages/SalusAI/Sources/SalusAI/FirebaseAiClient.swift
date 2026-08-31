// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/FirebaseAiClient.kt`.
//
// This is the only file in the app that talks to Firebase AI Logic. It must live behind
// `#if canImport(FirebaseAI)` because `swift test` runs on a macOS host that can never link the
// Firebase iOS frameworks: the `SalusAI` package builds and its tests pass without this file,
// and the file is only compiled into the real iOS app build, which resolves the SPM dependency.
#if canImport(FirebaseAI)

    import FirebaseAI
    import FirebaseAppCheck
    import FirebaseCore

    /// The only file in the app that talks to Firebase AI Logic.
    ///
    /// Everything the SDK reports is mapped onto this module's own `AiResult`, so no Firebase type ever
    /// reaches a repository, ViewModel or screen — the same rule `SalusPremium` applies to the store
    /// SDK.
    ///
    /// **Never crashes without a Google plist config.** That file is optional in this repo, so a
    /// contributor's build may have no `FirebaseApp` at all. `isConfigured` answers that question and
    /// `generate` short-circuits to `AiResult.unavailable` before it touches the SDK, which keeps a
    /// key-less build from failing out of `FirebaseAI`.
    ///
    /// The model is asked for a single, complete answer (no streaming): summaries are short and the UI
    /// shows them at once, so a partial response would only add state the screens do not need.
    public final class FirebaseAiClient: AiClient {
        public init() {}

        public var isConfigured: Bool {
            // Android: `FirebaseApp.getApps(appContext).isNotEmpty()`. Without an app there is no
            // default app to talk to, and the SDK's `FirebaseAI.firebaseAI()` entry point needs one.
            FirebaseApp.app() != nil
        }

        public func generate(_ prompt: AiPrompt) async -> AiResult {
            // Unconfigured builds never touch the SDK — the request is not sent.
            guard isConfigured else { return .unavailable }
            do {
                let model = FirebaseAI.firebaseAI().generativeModel(
                    modelName: modelName,
                    generationConfig: GenerationConfig(
                        // Low enough that the same stats do not produce a wildly different summary every
                        // run, high enough that the text does not read like a template.
                        temperature: temperature,
                        // Reasoning tokens are drawn from the same budget as the answer, so a model left
                        // to think freely spends the whole allowance before writing a word and the
                        // response comes back as MAX_TOKENS with no text at all. Summarising a handful of
                        // pre-computed averages needs no deliberation, so the level is pinned at the
                        // minimum rather than the budget being raised to absorb it.
                        maxOutputTokens: maxOutputTokens,
                        thinkingConfig: ThinkingConfig(thinkingLevel: .minimal)
                    ),
                    systemInstruction: ModelContent(parts: prompt.system)
                )
                // `String` conforms to `PartsRepresentable`, so a generated prompt flows straight in.
                let answer = try await model.generateContent(prompt.user).text
                // A safety block or a token limit hit on the first sentence both surface as no text.
                //
                // Markdown is stripped here, at the one place model text enters the app, so every
                // consumer — the summary screen and the PDF alike — is handed the plain text the
                // `AiClient` contract promises.
                if let answer, !answer.isEmpty {
                    return .success(answer.asPlainText())
                } else {
                    return .error(emptyResponse)
                }
            } catch {
                // A blank message is as useless as none at all — some SDK failures carry it.
                let message = error.localizedDescription
                return .error(message.isEmpty ? generationFailed : message)
            }
        }
    }

    // Android's `private companion object` constants, flattened to file scope. The camelCase names
    // follow this package's established private-constant spelling (e.g. `weeklyMinRecordDays`).
    private let modelName = "gemini-3.6-flash"
    private let temperature: Float = 0.4
    private let maxOutputTokens = 2048
    private let emptyResponse = "empty response"
    private let generationFailed = "AI request failed."

#endif // canImport(FirebaseAI)
