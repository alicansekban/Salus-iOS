// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/common/
// StageCopy.kt`.
//
// The words of the health stages, keyed by the catalog id (`smoking-health-stages.md`). A stage
// with no entry has no copy; `StageCopyTests` checks every `HealthStage.catalog` id against this,
// so a stage cannot be added to the catalog without its words. `@StringRes` ids become the typed
// `SmokingStrings.Key`, so the lookup stays in the one place that names catalog keys.

enum StageCopy {
    static func title(of stageId: String) -> String? {
        titleKey(of: stageId).map(SmokingStrings.localized)
    }

    static func statement(of stageId: String) -> String? {
        statementKey(of: stageId).map(SmokingStrings.localized)
    }

    private static func titleKey(of stageId: String) -> SmokingStrings.Key? {
        switch stageId {
        case "h_20m": .stageH20mTitle
        case "h_12h": .stageH12hTitle
        case "h_48h": .stageH48hTitle
        case "h_72h": .stageH72hTitle
        case "h_2w": .stageH2wTitle
        case "h_1mo": .stageH1moTitle
        case "h_1y": .stageH1yTitle
        case "h_5y": .stageH5yTitle
        case "h_10y": .stageH10yTitle
        case "h_15y": .stageH15yTitle
        default: nil
        }
    }

    private static func statementKey(of stageId: String) -> SmokingStrings.Key? {
        switch stageId {
        case "h_20m": .stageH20mStatement
        case "h_12h": .stageH12hStatement
        case "h_48h": .stageH48hStatement
        case "h_72h": .stageH72hStatement
        case "h_2w": .stageH2wStatement
        case "h_1mo": .stageH1moStatement
        case "h_1y": .stageH1yStatement
        case "h_5y": .stageH5yStatement
        case "h_10y": .stageH10yStatement
        case "h_15y": .stageH15yStatement
        default: nil
        }
    }
}
