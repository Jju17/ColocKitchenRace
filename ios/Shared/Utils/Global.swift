//
//  Global.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import Foundation
import SwiftUI

func ??<T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

// MARK: - Deep Linking

extension Notification.Name {
    /// Posted when the user taps a push notification.
    /// `userInfo` contains `"type"` (String) and `"data"` (original payload).
    static let ckrDeepLink = Notification.Name("ckrDeepLink")
}
