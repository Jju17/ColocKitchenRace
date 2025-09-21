//
//  ChallengeTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import ComposableArchitecture
import Dependencies
import SwiftUI
import MijickPopups

struct ChallengeTileFeature: Reducer {

    // MARK: - State
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        let challenge: Challenge
        let cohouseId: String

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

        case picture(PictureChoiceFeature.Action)
        case delegate(Delegate)

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

                    state.response = ChallengeResponse(
                        id: stableResponseId(challengeId: state.challenge.id, cohouseId: state.cohouseId),
                        challengeId: state.challenge.id,
                        cohouseId: state.cohouseId,
                        content: .noChoice,        // Will be replaced when submitting
                        status: .waiting,
                        submissionDate: date.now
                    )

                    // Watch du statut admin
                    let challengeId = state.challenge.id
                    let cohouseId = state.cohouseId
                    return .run { send in
                        for await status in responseClient.watchStatus(challengeId, cohouseId) {
                            await send(._statusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.statusWatcher, cancelInFlight: true)

                case let .submitTapped(payload):
                    guard var current = state.response else { return .none }
                    guard state.challenge.isActiveNow else { return .none }       // pas de soumission hors fenêtre
                    guard current.status != .validated else { return .none }      // verrou si déjà validé

                    state.isSubmitting = true
                    state.submitError = nil

                    switch payload {
                        case let .picture(data):
                            // 1) upload → _uploadFinished → 2) submit Firestore
                            let path = "challenges/\(current.challengeId)/responses/\(current.id).jpg"
                            return .run { send in
                                do {
                                    let url = try await storageClient.uploadImage(data, path)
                                    await send(._uploadFinished(.success(url)))
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
                        case let .success(urlString):
                            guard var current = state.response else { return .none }
                            current.content = .picture(urlString)
                            return submit(current)

                        case let .failure(error):
                            state.isSubmitting = false
                            state.submitError = error.localizedDescription
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
                            state.submitError = error.localizedDescription
                            return .none
                    }

                case let ._statusUpdated(status):
                    state.liveStatus = status
                    if var r = state.response { r.status = status; state.response = r }
                    return .none

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

    /// ID stable par (challenge, cohouse) pour éviter les doublons serveur
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
}

// MARK: - View Hook

struct ChallengeTileView: View {
    @Bindable var store: StoreOf<ChallengeTileFeature>

    var body: some View {
        VStack(spacing: 16) {
            HeaderView(
                title: store.challenge.title,
                startTime: store.challenge.startDate,
                endTime: store.challenge.endDate,
                challengeType: ChallengeType.fromContent(store.challenge.content)
            )

            BodyView(description: store.challenge.body)

            ChallengeContentView(
                challenge: store.challenge,
                response: store.response,
                selectedAnswer: $store.selectedAnswer,
                pictureStore: store.scope(state: \.picture, action: \.picture),
                onStart: { store.send(.startTapped) },
                onSubmit: { payload in store.send(.submitTapped(payload)) }
            )

            if store.isSubmitting { ProgressView("Submitting…") }
            if let err = store.submitError { Text(err).foregroundStyle(.red) }
            if let status = store.liveStatus { Text("Status: \(status.rawValue)") }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.CKRRandom))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
        .frame(width: UIScreen.main.bounds.width)
    }
}

struct HeaderView: View {
    var title: String
    var startTime: Date
    var endTime: Date
    var challengeType: ChallengeType

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Button {
                    Task {
                        await ChallengeInfoPopup.makeChallengeInfoPopup(for: challengeType).present()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.large)
                        .foregroundStyle(.black)
                }
            }
            .padding(.bottom)
            VStack(alignment: .center, spacing: 20) {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .font(.custom("BaksoSapi", size: 24))
                    .multilineTextAlignment(.center)
                HStack(alignment: .center, spacing: 50) {
                    VStack(spacing: 5) {
                        Text("START")
                        Text(startTime.formatted(.dateTime.day().month(.defaultDigits).hour().minute()))
                    }
                    VStack(spacing: 5) {
                        Text("END")
                        Text(endTime.formatted(.dateTime.day().month(.defaultDigits).hour().minute()))
                    }
                }
                .font(.custom("BaksoSapi", size: 11))
            }
        }
    }
}

struct BodyView: View {
    var description: String

    var body: some View {
        Text(description)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .font(.custom("BaksoSapi", size: 13))
            .lineSpacing(8)
            .multilineTextAlignment(.center)
            .padding(.top)
    }
}

@ViewBuilder
func ChallengeContentView(
    challenge: Challenge,
    response: ChallengeResponse?,
    selectedAnswer: Binding<Int?>,
    pictureStore: StoreOf<PictureChoiceFeature>,
    onStart: @escaping () -> Void,
    onSubmit: @escaping (ChallengeSubmitPayload) -> Void
) -> some View {
    VStack(spacing: 12) {
        if challenge.isActiveNow {
            if response == nil {
                Button("Start", action: onStart).buttonStyle(.borderedProminent)
            } else {
                switch challenge.content {
                    case .picture:
                        PictureChoiceView(store: pictureStore)
                        if let data = pictureStore.imageData {
                            Button("SUBMIT PHOTO") { onSubmit(.picture(data)) }
                                .buttonStyle(.borderedProminent)
                        }

                    case let .multipleChoice(mc):
                        MultipleChoiceView(choices: mc.choices, selectedIndex: selectedAnswer) {
                            if let idx = selectedAnswer.wrappedValue { onSubmit(.multipleChoice(idx)) }
                        }
                    case .singleAnswer:
                        SingleAnswerView { text in onSubmit(.singleAnswer(text)) }

                    case .noChoice:
                        NoChoiceView { onSubmit(.noChoice) }
                }
            }
        } else if !challenge.hasStarted {
            Text("Starts at \(challenge.startDate.formatted(.dateTime.day().month().hour().minute()))")
                .foregroundStyle(.secondary)
        } else {
            Text("Ended at \(challenge.endDate.formatted(.dateTime.day().month().hour().minute()))")
                .foregroundStyle(.secondary)
        }
    }
    .padding(.top)
}

#Preview {
    let challenge = Challenge.mock
    ChallengeTileView(
        store: Store(initialState: ChallengeTileFeature.State(id: challenge.id, challenge: challenge, cohouseId: ""),
                     reducer: { ChallengeTileFeature() })
    )
}

public enum ChallengeSubmitPayload: Equatable {
    case picture(Data)
    case multipleChoice(Int)
    case singleAnswer(String)
    case noChoice
}

extension ChallengeSubmitPayload {
    var requiresUpload: Bool {
        if case .picture = self { return true } else { return false }
    }
}
