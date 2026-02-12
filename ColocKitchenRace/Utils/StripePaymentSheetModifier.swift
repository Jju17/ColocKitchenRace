//
//  StripePaymentSheetModifier.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 12/02/2026.
//

import os
import StripePaymentSheet
import SwiftUI

// MARK: - Payment Sheet View Modifier

/// A SwiftUI ViewModifier that bridges the Stripe PaymentSheet into the SwiftUI/TCA world.
struct StripePaymentSheetModifier: ViewModifier {
    let isPresented: Bool
    let clientSecret: String?
    let customerId: String?
    let ephemeralKeySecret: String?
    let onCompletion: (PaymentSummaryFeature.PaymentResult) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                guard newValue else { return }
                presentPaymentSheet()
            }
    }

    private func presentPaymentSheet() {
        guard let clientSecret,
              let customerId,
              let ephemeralKeySecret
        else {
            Logger.paymentLog.error("Cannot present payment sheet: missing credentials")
            onCompletion(.failed("Payment configuration error"))
            return
        }

         var config = PaymentSheet.Configuration()
         config.merchantDisplayName = "Colocs Kitchen Race"
         config.customer = .init(id: customerId, ephemeralKeySecret: ephemeralKeySecret)
         config.allowsDelayedPaymentMethods = false
         config.returnURL = "colockitchenrace://stripe-redirect"
         config.applePay = .init(
             merchantId: "merchant.dev.rahier.colocskitchenrace",
             merchantCountryCode: "BE"
         )
        
         let paymentSheet = PaymentSheet(
             paymentIntentClientSecret: clientSecret,
             configuration: config
         )
        
         guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController?.topMostViewController()
         else {
             Logger.paymentLog.error("Cannot find root view controller for payment sheet presentation")
             onCompletion(.failed("Unable to present payment sheet"))
             return
         }
        
         paymentSheet.present(from: rootVC) { result in
             switch result {
             case .completed:
                 Logger.paymentLog.info("Payment completed successfully")
                 onCompletion(.completed)
             case .canceled:
                 Logger.paymentLog.info("Payment canceled by user")
                 onCompletion(.canceled)
             case let .failed(error):
                 Logger.paymentLog.error("Payment failed: \(error.localizedDescription)")
                 onCompletion(.failed(error.localizedDescription))
             }
         }
    }
}

// MARK: - UIViewController Helper

extension UIViewController {
    /// Walks the presented view controller chain to find the topmost one.
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController,
           let visible = nav.visibleViewController {
            return visible.topMostViewController()
        }
        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}

// MARK: - View Extension

extension View {
    func paymentSheet(
        isPresented: Bool,
        clientSecret: String?,
        customerId: String?,
        ephemeralKeySecret: String?,
        onCompletion: @escaping (PaymentSummaryFeature.PaymentResult) -> Void
    ) -> some View {
        modifier(StripePaymentSheetModifier(
            isPresented: isPresented,
            clientSecret: clientSecret,
            customerId: customerId,
            ephemeralKeySecret: ephemeralKeySecret,
            onCompletion: onCompletion
        ))
    }
}
