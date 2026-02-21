//
//  ChallengeTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import ComposableArchitecture
import SwiftUI
import MijickPopups

@Reducer
struct ChallengeTileFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        let challenge: Challenge
        let cohouseId: String
        let cohouseName: String

        var response: ChallengeResponse?
        var selectedAnswer: Int?

        var isSubmitting = false
        var submitError: String?

        var picture = PictureChoiceFeature.State()
        var liveStatus: ChallengeResponseStatus?
    }

    // MARK: - Actions
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startTapped
        case submitTapped(ChallengeSubmitPayload)

        case _uploadFinished(Result<String, Error>)
        case _submitFinished(Result<ChallengeResponse, Error>)
        case _statusUpdated(ChallengeResponseStatus)

        case onDisappear
        case picture(PictureChoiceFeature.Action)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case responseSubmitted(ChallengeResponse)
        }
    }

    enum CancelID { case statusWatcher, submit }

    // MARK: - Dependencies

    @Dependency(\.challengeResponseClient) var responseClient
    @Dependency(\.storageClient) var storageClient
    @Dependency(\.date) var date

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.picture, action: \.picture) { PictureChoiceFeature() }

        Reduce { state, action in
            switch action {
                case .binding:
                    return .none

                case .startTapped:
                    guard state.challenge.isActiveNow, state.response == nil else { return .none }

                    let newResponse = ChallengeResponse(
                        id: stableResponseId(challengeId: state.challenge.id, cohouseId: state.cohouseId),
                        challengeId: state.challenge.id,
                        cohouseId: state.cohouseId,
                        challengeTitle: state.challenge.title,
                        cohouseName: state.cohouseName,
                        content: .noChoice,        // Placeholder, overwritten on submit
                        status: .waiting,
                        submissionDate: date.now
                    )
                    state.response = newResponse

                    // Watch admin status
                    let challengeId = state.challenge.id
                    let cohouseId = state.cohouseId
                    return .run { send in
                        for await status in responseClient.watchStatus(challengeId, cohouseId) {
                            await send(._statusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.statusWatcher, cancelInFlight: true)

                case let .submitTapped(payload):
                    guard var current = state.response,
                          state.challenge.isActiveNow,                                      // No submission outside of timing window
                          current.status != .validated && current.status != .invalidated    // Lock if already validated/invalidated
                    else { return .none }

                    state.isSubmitting = true
                    state.submitError = nil

                    switch payload {
                        case let .picture(data):
                            // 1) upload → _uploadFinished → 2) submit to Firestore
                            let path = "challenges/\(current.challengeId)/responses/\(current.id).jpg"
                            return .run { send in
                                do {
                                    _ = try await storageClient.uploadImage(data, path)
                                    await send(._uploadFinished(.success(path)))
                                } catch {
                                    await send(._uploadFinished(.failure(error)))
                                }
                            }
                            .cancellable(id: CancelID.submit, cancelInFlight: true)

                        case let .multipleChoice(index):
                            current.content = .multipleChoice([index])
                            return submit(current)

                        case let .singleAnswer(text):
                            current.content = .singleAnswer(text)
                            return submit(current)

                        case .noChoice:
                            current.content = .noChoice
                            return submit(current)
                    }

                case let ._uploadFinished(result):
                    switch result {
                        case let .success(storagePath):
                            guard var current = state.response else { return .none }
                            current.content = .picture(storagePath)
                            return submit(current)

                        case let .failure(error):
                            state.isSubmitting = false
                            state.submitError = userFacingMessage(for: error)
                            return .none
                    }

                case let ._submitFinished(result):
                    state.isSubmitting = false
                    switch result {
                        case let .success(resp):
                            state.response = resp
                            state.liveStatus = resp.status
                            return .send(.delegate(.responseSubmitted(resp)))

                        case let .failure(error):
                            state.submitError = userFacingMessage(for: error)
                            return .none
                    }

                case let ._statusUpdated(status):
                    // Always update "live" status
                    state.liveStatus = status

                    // Update if response exists
                    if var resp = state.response {
                        resp.status = status
                        state.response = resp
                    }

                    // Stop watcher if final decision
                    if status == .validated || status == .invalidated {
                        return .cancel(id: CancelID.statusWatcher)
                    }
                    return .none

                case .onDisappear:
                    return .merge(
                      .cancel(id: CancelID.statusWatcher),
                      .cancel(id: CancelID.submit)
                    )

                case .picture, .delegate:
                    return .none
            }
        }
    }

    // MARK: - Helpers
    private func submit(_ response: ChallengeResponse) -> Effect<Action> {
        .run { send in
            do {
                let saved = try await responseClient.submit(response)
                await send(._submitFinished(.success(saved)))
            } catch {
                await send(._submitFinished(.failure(error)))
            }
        }
        .cancellable(id: CancelID.submit, cancelInFlight: true)
    }

    /// Stable ID by (challenge, cohouse) to avoid duplicate on server-side
    private func stableResponseId(challengeId: UUID, cohouseId: String) -> UUID {
        let base = "\(challengeId.uuidString)#\(cohouseId)"
        var hasher = Hasher(); hasher.combine(base)
        let h = UInt64(bitPattern: Int64(hasher.finalize()))
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: h) { uuidBytes.replaceSubrange(0..<8, with: $0) }
        withUnsafeBytes(of: h &* 0x9e3779b97f4a7c15) { uuidBytes.replaceSubrange(8..<16, with: $0) }
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    // MARK: - Error Mapping

    private func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        switch (nsError.domain, nsError.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet):
            return "No Internet connection. Check your connection and try again."
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return "The request timed out. Please try again in a moment."
        default:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Header Colors

private let headerColors: [Color] = [.ckrCoral, .ckrSky, .ckrLavender, .ckrMint, .ckrGold]

// MARK: - View

struct ChallengeTileView: View {
    @Bindable var store: StoreOf<ChallengeTileFeature>
    @Environment(\.colorScheme) var colorScheme
    var colorIndex: Int = 0

    private var bg: Color { colorScheme == .dark ? Color(white: 0.13) : .white }
    private var headerColor: Color { headerColors[abs(colorIndex) % headerColors.count] }

    var body: some View {
        let isFinal = store.liveStatus == .validated || store.liveStatus == .invalidated

        VStack(spacing: 0) {
            // === HEADER — colored background ===
            headerSection

            // === BODY — white/dark background ===
            bodySection(isFinal: isFinal)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 16, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.liveStatus) { _, new in
            if new == .validated {
                _ = ConfettiCannon()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Top row: countdown badge (right-aligned)
            HStack {
                Spacer()
                if store.challenge.isActiveNow {
                    CountdownBadge(endDate: store.challenge.endDate, accentColor: headerColor)
                }
            }

            // Title
            Text(store.challenge.title.uppercased())
                .font(.custom("BaksoSapi", size: 26, relativeTo: .title))
                .fontWeight(.black)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Dates
            HStack(spacing: 30) {
                dateItem("START", store.challenge.startDate)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 20, weight: .bold))
                dateItem("END", store.challenge.endDate)
            }

            // Type + Points badges
            HStack(spacing: 12) {
                typeBadge
                if let points = store.challenge.points {
                    pointsBadge(points)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(headerColor)
    }

    private func dateItem(_ label: String, _ date: Date) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.custom("BaksoSapi", size: 11))
                .foregroundStyle(.white.opacity(0.7))
                .fontWeight(.bold)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(date.formatted(.dateTime.day().month(.defaultDigits)))
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(date.formatted(.dateTime.hour().minute()))
                }
            }
            .font(.custom("BaksoSapi", size: 13))
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var typeBadge: some View {
        let (label, icon) = challengeTypeInfo(store.challenge.content.type)
        return Button {
            Task {
                await ChallengeInfoPopup.makeChallengeInfoPopup(
                    for: store.challenge.content.type,
                    accentColor: headerColor
                ).present()
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.custom("BaksoSapi", size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pointsBadge(_ points: Int) -> some View {
        Button {
            Task {
                await ChallengeInfoPopup(
                    symbol: "star.fill",
                    title: "Points",
                    description: "This challenge is worth \(points) point\(points > 1 ? "s" : ""). Complete it to add them to your coloc's score!",
                    accentColor: headerColor
                ).present()
            }
        } label: {
            Text("\(points) pt\(points > 1 ? "s" : "")")
                .font(.custom("BaksoSapi", size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func challengeTypeInfo(_ type: ChallengeType) -> (String, String) {
        switch type {
        case .picture: ("Photo", "camera.fill")
        case .multipleChoice: ("QCM", "list.bullet")
        case .singleAnswer: ("Text", "text.cursor")
        case .noChoice: ("Action", "checkmark")
        }
    }

    // MARK: - Body

    private func bodySection(isFinal: Bool) -> some View {
        let isWaitingReview = store.response != nil
            && store.liveStatus == .waiting
            && !store.isSubmitting

        return VStack(spacing: 16) {
            // Description (scrollable if long)
            ScrollView {
                Text(store.challenge.body)
                    .font(.custom("BaksoSapi", size: 14))
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 8)
            }

            // Content (answer area, waiting state, or final status)
            if isFinal {
                FinalStatusView(status: store.liveStatus)
            } else if isWaitingReview {
                WaitingReviewView()
            } else {
                ChallengeContentView(
                    challenge: store.challenge,
                    response: store.response,
                    selectedAnswer: $store.selectedAnswer,
                    pictureStore: store.scope(state: \.picture, action: \.picture),
                    onStart: { store.send(.startTapped) },
                    onSubmit: { store.send(.submitTapped($0)) },
                    isSubmitting: store.isSubmitting
                )
            }

            // Feedback
            if store.isSubmitting {
                ProgressView("Submitting…")
                    .font(.custom("BaksoSapi", size: 16))
                    .padding()
            }

            if let err = store.submitError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg)
    }
}

#Preview {
    let challenge = Challenge.mock
    ChallengeTileView(
        store: Store(initialState: ChallengeTileFeature.State(id: challenge.id, challenge: challenge, cohouseId: "cohouse_preview", cohouseName: "Preview House"),
                     reducer: { ChallengeTileFeature() }),
        colorIndex: 0
    )
}
