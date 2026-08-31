// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/AiClient.kt`.

/// The outcome of a single generation request.
///
/// `.unavailable` and `.error` are deliberately distinct: the first means the feature cannot run
/// on this build at all (no Firebase configuration), which the UI presents as a disabled state,
/// while the second is a transient failure the user can retry.
public enum AiResult: Equatable, Sendable {
    /// The model answered with non-blank text.
    ///
    /// `text` is plain text, never markdown: it is rendered by a SwiftUI `Text` and drawn onto a
    /// PDF canvas, neither of which interprets syntax. Implementations strip it.
    case success(String)

    /// No Firebase configuration on this build — the request was never sent.
    case unavailable

    /// Network, quota, safety or any other SDK failure, already reduced to a message.
    case error(String)
}

/// The seam every AI feature talks to.
///
/// Implementations map whatever their SDK reports onto `AiResult`, so no vendor type ever reaches
/// a repository, ViewModel or screen — the same rule `SalusPremium` applies to the store SDK.
/// Consumers of this module never import Firebase.
public protocol AiClient: Sendable {
    /// Whether a request can be sent at all. `false` makes `generate` return `AiResult.unavailable`.
    var isConfigured: Bool { get }

    /// Sends `prompt` to the model and waits for the full answer.
    ///
    /// Never throws for an SDK failure — every error is returned as `AiResult.error`. Cancellation
    /// of the calling task is still honoured: Swift's runtime cancels the awaited SDK call, and a
    /// cancellation that surfaces is reported rather than swallowed into the generic failure.
    func generate(_ prompt: AiPrompt) async -> AiResult
}
