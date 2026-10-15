// No Kotlin twin. Android's `ReminderDeepLink.Smoking` builds the whole back stack in one go; iOS
// pushes onto the live More stack, where earlier pushes, Back and the More row itself have left it
// in a state a notification tap has to read. The decision is a pure function so it can be pinned
// without a shell.

/// What sits on top of More's stack from the smoking screens: the main screen (`stageId == nil`) or
/// the timeline highlighting `stageId` over it, and the depth the stack had with it on top.
///
/// Seeded by a reminder tap and by More pushing `SmokingKey` itself; ``SmokingMilestoneRoute``
/// compares both fields, because the same depth with another stage is a different highlight, not a
/// duplicate.
public struct SmokingPushedScreens: Equatable, Sendable {
    public let stageId: String?
    public let depth: Int

    public init(stageId: String?, depth: Int) {
        self.stageId = stageId
        self.depth = depth
    }
}

/// The stack changes a milestone notification asks for, in the order they apply: `pops` timelines,
/// then the main screen if `pushesMain`, then the timeline for `timelineStageId`. `memo` is what the
/// stack looks like afterwards.
public struct SmokingMilestoneRoute: Equatable, Sendable {
    public let pops: Int
    public let pushesMain: Bool
    public let timelineStageId: String?
    public let memo: SmokingPushedScreens

    public init(pops: Int, pushesMain: Bool, timelineStageId: String?, memo: SmokingPushedScreens) {
        self.pops = pops
        self.pushesMain = pushesMain
        self.timelineStageId = timelineStageId
        self.memo = memo
    }

    /// The tap is for what is already on top.
    public var isNoOp: Bool {
        pops == 0 && !pushesMain && timelineStageId == nil
    }

    /// - Parameters:
    ///   - currentDepth: how many entries More's stack holds now.
    ///   - memo: what the last reminder tap or More push left, if anything.
    ///   - stageId: the stage the notification announced, `nil` for a milestone without one.
    public static func make(currentDepth: Int, memo: SmokingPushedScreens?, stageId: String?) -> Self {
        var depth = currentDepth
        var pops = 0
        var pushesMain = false
        switch top(currentDepth: currentDepth, memo: memo) {
        case let .timeline(shown):
            if shown == stageId {
                return Self(
                    pops: 0,
                    pushesMain: false,
                    timelineStageId: nil,
                    memo: SmokingPushedScreens(stageId: stageId, depth: depth)
                )
            }
            // Replaces the older highlight instead of stacking a second timeline; a milestone with
            // no stage ends on the main screen this way.
            pops = 1
            depth -= 1

        case .main:
            break

        case .none:
            pushesMain = true
            depth += 1
        }
        if stageId != nil {
            depth += 1
        }
        return Self(
            pops: pops,
            pushesMain: pushesMain,
            timelineStageId: stageId,
            memo: SmokingPushedScreens(stageId: stageId, depth: depth)
        )
    }

    private enum Top {
        case main
        case timeline(stageId: String)
        case none
    }

    private static func top(currentDepth: Int, memo: SmokingPushedScreens?) -> Top {
        guard let memo else { return .none }
        if memo.depth == currentDepth {
            return memo.stageId.map(Top.timeline(stageId:)) ?? .main
        }
        // Back from the timeline a notification opened leaves the main screen on top, one entry
        // below where the memo put the stack. Any navigate clears the memo, so a pop is the only
        // way to reach that depth.
        if memo.stageId != nil, currentDepth == memo.depth - 1 {
            return .main
        }
        return .none
    }
}
