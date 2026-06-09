//
//  TelemetryEvent.swift
//  DialSplit
//
//  匿名利用イベント定義
//  目的：
//  - よく使われる機能 / 全く使われていない機能の特定
//  - 操作パターンの把握（手間削減のため）
//  - 設定の分布把握
//

import Foundation

enum TelemetryEvent {

    // MARK: - ダイアル操作

    /// ダイアルを回した（最初の一回／セッションごと）
    case dialEngaged(panel: String, kind: DialKind)
    /// テンキーで確定
    case numpadConfirmed(panel: String, kind: DialKind)
    /// ステッパー +/- ボタン使用
    case stepperUsed(panel: String, kind: DialKind)

    // MARK: - 金額ダイアルステップ

    /// ステップボタンをタップして選択
    case stepSelected(value: Int)
    /// ステップを長押しで編集開始
    case stepLongPressed(index: Int)
    /// ステップを長押し編集で確定
    case stepEdited(index: Int, oldValue: Int, newValue: Int)

    // MARK: - ロック

    case peopleLockToggled(locked: Bool)
    case allLockToggled(locked: Bool)

    // MARK: - パネルスタイル（メイン画面下部）

    case panelStyleToggled(open: Bool)
    case colorSwatchTapped(hueBucket: String)   // "black" / "white" / "hue_60" etc.
    case toneSwatchTapped(tone: Int)
    case backgroundChanged(style: String)
    case brightnessAdjusted

    // MARK: - 設定画面

    case settingsOpened
    case namePresetChanged(presetIndex: Int)
    case panelNameEdited(index: Int)
    case dialSettingsOpened
    case dialTuningPresetChanged(presetId: Int)
    case appearanceChanged(mode: String)
    case fontScaleChanged(scale: Int)
    case showDialStepperToggled(enabled: Bool)
    case stepEditedInSettings(index: Int, newValue: Int)
    case aboutAppTapped

    // MARK: - 開発者を応援

    case supportSheetOpened(kind: SupportKind)
    case tipPurchaseInitiated(productId: String)
    case tipPurchaseSucceeded(productId: String)
    case tipPurchaseFailed(productId: String)
    case adRewardEarned

    // MARK: - セッション・ハイレベル

    /// アプリ起動後最初のダイアル操作までの時間（秒）
    case timeToFirstInteraction(seconds: Int)
    /// 1セッションあたりの操作集計（バックグラウンド遷移時）
    case sessionSummary(dialChanges: Int, numpadUses: Int, stepperUses: Int, settingsOpens: Int)

    // MARK: - 種別 enum

    enum DialKind: String {
        case people
        case amount
    }

    enum SupportKind: String {
        case tip
        case ad
    }

    // MARK: - 名前・パラメータ

    var name: String {
        switch self {
        case .dialEngaged:              return "dial_engaged"
        case .numpadConfirmed:          return "numpad_confirmed"
        case .stepperUsed:              return "stepper_used"
        case .stepSelected:             return "step_selected"
        case .stepLongPressed:          return "step_long_pressed"
        case .stepEdited:               return "step_edited"
        case .peopleLockToggled:        return "people_lock_toggled"
        case .allLockToggled:           return "all_lock_toggled"
        case .panelStyleToggled:        return "panel_style_toggled"
        case .colorSwatchTapped:        return "color_swatch_tapped"
        case .toneSwatchTapped:         return "tone_swatch_tapped"
        case .backgroundChanged:        return "background_changed"
        case .brightnessAdjusted:       return "brightness_adjusted"
        case .settingsOpened:           return "settings_opened"
        case .namePresetChanged:        return "name_preset_changed"
        case .panelNameEdited:          return "panel_name_edited"
        case .dialSettingsOpened:       return "dial_settings_opened"
        case .dialTuningPresetChanged:  return "dial_tuning_changed"
        case .appearanceChanged:        return "appearance_changed"
        case .fontScaleChanged:         return "font_scale_changed"
        case .showDialStepperToggled:   return "dial_stepper_toggled"
        case .stepEditedInSettings:     return "step_edited_in_settings"
        case .aboutAppTapped:           return "about_app_tapped"
        case .supportSheetOpened:       return "support_sheet_opened"
        case .tipPurchaseInitiated:    return "tip_purchase_initiated"
        case .tipPurchaseSucceeded:    return "tip_purchase_succeeded"
        case .tipPurchaseFailed:        return "tip_purchase_failed"
        case .adRewardEarned:           return "ad_reward_earned"
        case .timeToFirstInteraction:  return "time_to_first_interaction"
        case .sessionSummary:           return "session_summary"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .dialEngaged(let panel, let kind),
             .numpadConfirmed(let panel, let kind),
             .stepperUsed(let panel, let kind):
            return ["panel": panel, "kind": kind.rawValue]

        case .stepSelected(let value):
            return ["value": value]

        case .stepLongPressed(let index):
            return ["index": index]

        case .stepEdited(let index, let old, let new):
            return ["index": index, "old_value": old, "new_value": new]

        case .stepEditedInSettings(let index, let newValue):
            return ["index": index, "new_value": newValue]

        case .peopleLockToggled(let locked),
             .allLockToggled(let locked):
            return ["locked": locked ? 1 : 0]

        case .panelStyleToggled(let open):
            return ["open": open ? 1 : 0]

        case .colorSwatchTapped(let hueBucket):
            return ["hue_bucket": hueBucket]

        case .toneSwatchTapped(let tone):
            return ["tone": tone]

        case .backgroundChanged(let style):
            return ["style": style]

        case .namePresetChanged(let i),
             .panelNameEdited(let i):
            return ["index": i]

        case .dialTuningPresetChanged(let id):
            return ["preset_id": id]

        case .appearanceChanged(let mode):
            return ["mode": mode]

        case .fontScaleChanged(let scale):
            return ["scale": scale]

        case .showDialStepperToggled(let enabled):
            return ["enabled": enabled ? 1 : 0]

        case .supportSheetOpened(let kind):
            return ["kind": kind.rawValue]

        case .tipPurchaseInitiated(let id),
             .tipPurchaseSucceeded(let id),
             .tipPurchaseFailed(let id):
            return ["product_id": id]

        case .timeToFirstInteraction(let s):
            return ["seconds": s]

        case .sessionSummary(let dials, let numpads, let steppers, let settings):
            return [
                "dial_changes": dials,
                "numpad_uses": numpads,
                "stepper_uses": steppers,
                "settings_opens": settings,
            ]

        case .brightnessAdjusted,
             .settingsOpened,
             .dialSettingsOpened,
             .aboutAppTapped,
             .adRewardEarned:
            return nil
        }
    }
}
