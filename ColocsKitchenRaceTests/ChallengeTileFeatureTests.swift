//
//  ChallengeTileFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct ChallengeTileFeatureTests {

    // MARK: - Helpers

    private func makeActiveChallenge() -> Challenge {
        Challenge(
            id: UUID(),
            title: "Test Challenge",
            startDate: Date.distantPast,
            endDate: Date.distantFuture,
            body: "Test body",
            content: .noChoice(NoChoiceContent())
        )
    }

    private func makeExpiredChallenge() -> Challenge {
        Challenge(
            id: UUID(),
            title: "Expired",
            startDate: Date.distantPast,
            endDate: Date.distantPast,
            body: "Test",
            content: .noChoice(NoChoiceContent())
        )
    }

    private func makeFutureChallenge() -> Challenge {
        Challenge(
            id: UUID(),
            title: "Future",
            startDate: Date.distantFuture,
            endDate: Date.distantFuture,
            body: "Test",
            content: .noChoice(NoChoiceContent())
        )
    }

    private func makeState(for challenge: Challenge, response: ChallengeResponse? = nil) -> ChallengeTileFeature.State {
        ChallengeTileFeature.State(
            id: challenge.id,
            challenge: challenge,
            cohouseId: "cohouse-1",
            cohouseName: "Test House",
            response: response
        )
    }

    // MARK: - Start

//    @Test("startTapped creates response and watches status")
//    func startTapped_activeChallenge() async {
//        let challenge = makeActiveChallenge()
//
//        let store = TestStore(initialState: makeState(for: challenge)) {
//            ChallengeTileFeature()
//        } withDependencies: {
//            $0.challengeResponseClient.watchStatus = { _, _ in
//                AsyncStream { $0.finish() }
//            }
//            $0.date = .constant(Date())
//        }
//
//        await store.send(.startTapped) {
//            $0.response = ChallengeResponse(
//                id: $0.response!.id, // stable UUID generated
//                challengeId: challenge.id,
//                cohouseId: "cohouse-1",
//                challengeTitle: challenge.title,
//                cohouseName: "Test House",
//                content: .noChoice,
//                status: .waiting,
//                submissionDate: store.dependencies.date.now
//            )
//        }
//    }

    @Test("startTapped does nothing when challenge is expired")
    func startTapped_expired() async {
        let challenge = makeExpiredChallenge()

        let store = TestStore(initialState: makeState(for: challenge)) {
            ChallengeTileFeature()
        }

        await store.send(.startTapped)
    }

    @Test("startTapped does nothing when challenge hasn't started")
    func startTapped_future() async {
        let challenge = makeFutureChallenge()

        let store = TestStore(initialState: makeState(for: challenge)) {
            ChallengeTileFeature()
        }

        await store.send(.startTapped)
    }

    @Test("startTapped does nothing when response already exists")
    func startTapped_alreadyStarted() async {
        let challenge = makeActiveChallenge()
        let existingResponse = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: challenge.title, cohouseName: "Test House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: existingResponse)) {
            ChallengeTileFeature()
        }

        await store.send(.startTapped)
    }

    // MARK: - Submit NoChoice

    @Test("Submit noChoice payload saves response")
    func submitNoChoice() async {
        let challenge = makeActiveChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Test", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        var submittedResponse: ChallengeResponse?

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.challengeResponseClient.submit = { resp in
                submittedResponse = resp
                return resp
            }
        }

        await store.send(.submitTapped(.noChoice)) {
            $0.isSubmitting = true
            $0.submitError = nil
        }

        await store.receive(\._submitFinished) {
            $0.isSubmitting = false
            $0.response = submittedResponse
            $0.liveStatus = .waiting
        }

        #expect(submittedResponse?.content == .noChoice)
    }

    // MARK: - Submit MultipleChoice

    @Test("Submit multipleChoice payload saves selected index")
    func submitMultipleChoice() async {
        let challenge = Challenge(
            id: UUID(), title: "QCM", startDate: .distantPast, endDate: .distantFuture,
            body: "Test", content: .multipleChoice(MultipleChoiceContent(
                choices: ["A", "B", "C", "D"], correctAnswerIndex: 2
            ))
        )
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "QCM", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.challengeResponseClient.submit = { resp in resp }
        }

        await store.send(.submitTapped(.multipleChoice(1))) {
            $0.isSubmitting = true
            $0.submitError = nil
        }

        await store.receive(\._submitFinished) {
            $0.isSubmitting = false
            var updatedResponse = response
            updatedResponse.content = .multipleChoice([1])
            $0.response = updatedResponse
            $0.liveStatus = .waiting
        }
    }

    // MARK: - Submit SingleAnswer

    @Test("Submit singleAnswer payload saves text")
    func submitSingleAnswer() async {
        let challenge = Challenge(
            id: UUID(), title: "Riddle", startDate: .distantPast, endDate: .distantFuture,
            body: "What?", content: .singleAnswer(SingleAnswerContent())
        )
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Riddle", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.challengeResponseClient.submit = { resp in resp }
        }

        await store.send(.submitTapped(.singleAnswer("42"))) {
            $0.isSubmitting = true
        }

        await store.receive(\._submitFinished) {
            $0.isSubmitting = false
            var updatedResponse = response
            updatedResponse.content = .singleAnswer("42")
            $0.response = updatedResponse
            $0.liveStatus = .waiting
        }
    }

    // MARK: - Submit Guards

    @Test("Submit does nothing when response is nil")
    func submitWithoutResponse() async {
        let challenge = makeActiveChallenge()

        let store = TestStore(initialState: makeState(for: challenge)) {
            ChallengeTileFeature()
        }

        await store.send(.submitTapped(.noChoice))
    }

    @Test("Submit does nothing when challenge is expired")
    func submitExpired() async {
        let challenge = makeExpiredChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Expired", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        }

        await store.send(.submitTapped(.noChoice))
    }

    @Test("Submit does nothing when already validated")
    func submitAlreadyValidated() async {
        let challenge = makeActiveChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Test", cohouseName: "House",
            content: .noChoice, status: .validated, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        }

        await store.send(.submitTapped(.noChoice))
    }

    // MARK: - Submit Error

    @Test("Submit failure sets submitError")
    func submitError() async {
        let challenge = makeActiveChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Test", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.challengeResponseClient.submit = { _ in
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            }
        }

        await store.send(.submitTapped(.noChoice)) {
            $0.isSubmitting = true
        }

        await store.receive(\._submitFinished) {
            $0.isSubmitting = false
            $0.submitError = "No Internet connection. Check your connection and try again."
        }
    }

    // MARK: - Status Updates

    @Test("Status update to validated cancels watcher")
    func statusUpdated_validated() async {
        let challenge = makeActiveChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Test", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        }

        await store.send(._statusUpdated(.validated)) {
            $0.liveStatus = .validated
            var updatedResponse = response
            updatedResponse.status = .validated
            $0.response = updatedResponse
        }
    }

    @Test("Status update to invalidated cancels watcher")
    func statusUpdated_invalidated() async {
        let challenge = makeActiveChallenge()
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Test", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        }

        await store.send(._statusUpdated(.invalidated)) {
            $0.liveStatus = .invalidated
            var updatedResponse = response
            updatedResponse.status = .invalidated
            $0.response = updatedResponse
        }
    }

    @Test("Status update to waiting keeps watching")
    func statusUpdated_waiting() async {
        let challenge = makeActiveChallenge()

        let store = TestStore(initialState: makeState(for: challenge)) {
            ChallengeTileFeature()
        }

        await store.send(._statusUpdated(.waiting)) {
            $0.liveStatus = .waiting
        }
    }

    // MARK: - onDisappear

    @Test("onDisappear cancels all effects")
    func onDisappear() async {
        let challenge = makeActiveChallenge()

        let store = TestStore(initialState: makeState(for: challenge)) {
            ChallengeTileFeature()
        }

        await store.send(.onDisappear)
    }

    // MARK: - Picture Upload Flow

    @Test("Submit picture uploads first, then submits")
    func submitPicture() async {
        let challenge = Challenge(
            id: UUID(), title: "Photo", startDate: .distantPast, endDate: .distantFuture,
            body: "Take a photo", content: .picture(PictureContent())
        )
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Photo", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )
        let fakeImageData = Data([0xFF, 0xD8]) // JPEG magic bytes

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.storageClient.uploadImage = { _, path in
                return "https://example.com/image.jpg"
            }
            $0.challengeResponseClient.submit = { resp in resp }
        }

        await store.send(.submitTapped(.picture(fakeImageData))) {
            $0.isSubmitting = true
            $0.submitError = nil
        }

        // First: upload finishes
        let expectedPath = "challenges/\(challenge.id)/responses/\(response.id).jpg"
        await store.receive(\._uploadFinished)

        // Then: submit finishes
        await store.receive(\._submitFinished) {
            $0.isSubmitting = false
            var updatedResponse = response
            updatedResponse.content = .picture(expectedPath)
            $0.response = updatedResponse
            $0.liveStatus = .waiting
        }
    }

    @Test("Upload failure sets error")
    func uploadFailure() async {
        let challenge = Challenge(
            id: UUID(), title: "Photo", startDate: .distantPast, endDate: .distantFuture,
            body: "Take a photo", content: .picture(PictureContent())
        )
        let response = ChallengeResponse(
            id: UUID(), challengeId: challenge.id, cohouseId: "cohouse-1",
            challengeTitle: "Photo", cohouseName: "House",
            content: .noChoice, status: .waiting, submissionDate: Date()
        )

        let store = TestStore(initialState: makeState(for: challenge, response: response)) {
            ChallengeTileFeature()
        } withDependencies: {
            $0.storageClient.uploadImage = { _, _ in
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
            }
        }

        await store.send(.submitTapped(.picture(Data()))) {
            $0.isSubmitting = true
        }

        await store.receive(\._uploadFinished) {
            $0.isSubmitting = false
            $0.submitError = "The request timed out. Please try again in a moment."
        }
    }
}
