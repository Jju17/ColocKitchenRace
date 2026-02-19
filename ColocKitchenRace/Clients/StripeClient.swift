//
//  StripeClient.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 12/02/2026.
//

import ComposableArchitecture
import FirebaseFunctions
import os

// MARK: - Types

struct PaymentIntentResult: Equatable {
    var clientSecret: String
    var customerId: String
    var ephemeralKeySecret: String
    var paymentIntentId: String
}

enum StripeError: Error, Equatable {
    case paymentIntentCreationFailed(String)
    case invalidResponse
}

// MARK: - Client Interface

@DependencyClient
struct StripeClient {
    var createPaymentIntent: @Sendable (
        _ gameId: String,
        _ cohouseId: String,
        _ amountCents: Int,
        _ participantCount: Int
    ) async throws -> PaymentIntentResult
}

// MARK: - Implementations

extension StripeClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        createPaymentIntent: { gameId, cohouseId, amountCents, participantCount in
            // Demo mode: return mock payment intent without hitting Stripe
            if DemoMode.isActive {
                Logger.paymentLog.info("[Demo] Returning mock payment intent")
                return PaymentIntentResult(
                    clientSecret: "pi_demo_secret_xxx",
                    customerId: "cus_demo_xxx",
                    ephemeralKeySecret: "ek_demo_xxx",
                    paymentIntentId: "pi_demo_xxx"
                )
            }

            Logger.paymentLog.info("Creating payment intent for game \(gameId), cohouse \(cohouseId), amount \(amountCents) cents, \(participantCount) participants")

            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("createPaymentIntent")

            let data: [String: Any] = [
                "gameId": gameId,
                "cohouseId": cohouseId,
                "amountCents": amountCents,
                "participantCount": participantCount
            ]

            let result = try await callable.call(data)

            guard let dict = result.data as? [String: Any],
                  let clientSecret = dict["clientSecret"] as? String,
                  let customerId = dict["customerId"] as? String,
                  let ephemeralKeySecret = dict["ephemeralKeySecret"] as? String,
                  let paymentIntentId = dict["paymentIntentId"] as? String
            else {
                Logger.paymentLog.error("Invalid response from createPaymentIntent")
                throw StripeError.invalidResponse
            }

            Logger.paymentLog.info("Payment intent created successfully: \(paymentIntentId)")

            return PaymentIntentResult(
                clientSecret: clientSecret,
                customerId: customerId,
                ephemeralKeySecret: ephemeralKeySecret,
                paymentIntentId: paymentIntentId
            )
        }
    )

    // MARK: Test

    static let testValue = Self()

    // MARK: Preview

    static let previewValue = Self(
        createPaymentIntent: { _, _, _, _ in
            PaymentIntentResult(
                clientSecret: "pi_test_secret_xxx",
                customerId: "cus_test_xxx",
                ephemeralKeySecret: "ek_test_xxx",
                paymentIntentId: "pi_test_xxx"
            )
        }
    )
}

// MARK: - Registration

extension DependencyValues {
    var stripeClient: StripeClient {
        get { self[StripeClient.self] }
        set { self[StripeClient.self] = newValue }
    }
}
