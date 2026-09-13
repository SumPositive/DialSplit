//
//  SnapshotSupport.swift
//  DialSplit
//

import Foundation

enum SnapshotSupport {
    /// fastlane snapshot による撮影中なら true。
    /// SnapshotHelper が UserDefaults 経由で -FASTLANE_SNAPSHOT YES をセットする。
    static var isRunningSnapshot: Bool {
        UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")
    }
}
