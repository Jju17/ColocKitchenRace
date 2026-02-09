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

                    state.response = ChallengeResponse(
                        id: stableResponseId(challengeId: state.challenge.id, cohouseId: state.cohouseId),
                        challengeId: state.challenge.id,
                        cohouseId: state.cohouseId,
                        challengeTitle: state.challenge.title,
                        cohouseName: state.cohouseName,
                        content: .noChoice,        // Will be replaced when submitting
                        status: .waiting,
                        submissionDate: date.now
                    )

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

    // MARK: - Error mapping (A)

    private func userFacingMessage(for error: Error) -> String {
        // Very simple to start, we can afterward go more into details with network/HTTP/timeout errors
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

// MARK: - View Hook

struct ChallengeTileView: View {
    @Bindable var store: StoreOf<ChallengeTileFeature>
    @Environment(\.colorScheme) var colorScheme

    private var bg: Color { colorScheme == .dark ? Color(white: 0.13) : .white }
    private var text: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        let isFinal = store.liveStatus == .validated || store.liveStatus == .invalidated

        VStack(spacing: 24) {
            // === HEADER ===
            ChallengeHeaderView(
                title: store.challenge.title,
                startDate: store.challenge.startDate,
                endDate: store.challenge.endDate,
                challengeType: store.challenge.content.type
            )

            // === DESCRIPTION ===
            ScrollView {
                Text(store.challenge.body)
                    .font(.custom("BaksoSapi", size: 14))
                    .foregroundColor(text.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 8)
            }

            // === CONTENT ===
            if isFinal {
                FinalStatusView(status: store.liveStatus)
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

            // === FEEDBACK ===
            if store.isSubmitting {
                ProgressView("Envoi en cours…")
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

//            if let status = store.liveStatus, !isFinal {
//                StatusBadge(status: status)
//                    .padding(.top, 8)
//            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(bg)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.green.opacity(0.3), lineWidth: 2)
        )
        .onChange(of: store.liveStatus) { _, new in
            if new == .validated {
                _ = ConfettiCannon()
            }
        }
    }
}

struct ChallengeHeaderView: View {
    let title: String
    let startDate: Date
    let endDate: Date
    let challengeType: ChallengeType

    @Environment(\.colorScheme) var colorScheme
    private var text: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                InfoButton(challengeType: challengeType)
                Spacer()
            }
            .backgroundStyle(.red)

            VStack(spacing: 16) {
                Text(title.uppercased())
                    .font(.custom("BaksoSapi", size: 26, relativeTo: .title))
                    .fontWeight(.black)
                    .foregroundColor(text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 40) {
                    dateItem("START", startDate)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.green)
                        .font(.system(size: 26, weight: .bold))
                    dateItem("END", endDate)
                }
                .font(.custom("BaksoSapi", size: 14))
            }
            .backgroundStyle(.green)
        }
    }

    private func dateItem(_ label: String, _ date: Date) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.custom("BaksoSapi", size: 12))
                .foregroundColor(.green)
                .fontWeight(.bold)

            VStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(date.formatted(.dateTime.day().month(.defaultDigits)))
                }
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(date.formatted(.dateTime.hour().minute()))
                }
            }
            .font(.custom("BaksoSapi", size: 14))
            .foregroundColor(.secondary)
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
    onSubmit: @escaping (ChallengeSubmitPayload) -> Void,
    isSubmitting: Bool
) -> some View {
    VStack(spacing: 12) {
        if challenge.isActiveNow {
            if response == nil {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("START")
                    }
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.CKRPurple)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start the challenge")
                .accessibilityHint("Begin your participation in this challenge.")
            } else {
                switch challenge.content {
                    case .picture:
                        PictureChoiceView(
                            store: pictureStore,
                            onSubmit: { onSubmit(.picture($0)) },
                            isSubmitting: isSubmitting
                        )
                        if pictureStore.imageData == nil {
                            Text("Select a photo, then submit.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let data = pictureStore.imageData {
                            Button("SUBMIT PHOTO") { onSubmit(.picture(data)) }
                                .buttonStyle(.borderedProminent)
                                .accessibilityLabel("Submit photo")
                                .accessibilityHint("Send your photo for validation.")
                        }

                    case let .multipleChoice(mc):
                        MultipleChoiceView(choices: mc.choices, selectedIndex: selectedAnswer, isSubmitting: isSubmitting) {
                            if let idx = selectedAnswer.wrappedValue { onSubmit(.multipleChoice(idx)) }
                        }
                        if selectedAnswer.wrappedValue == nil {
                            Text("Choose an answer, then confirm.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .singleAnswer:
                        SingleAnswerView(isSubmitting: isSubmitting) { text in onSubmit(.singleAnswer(text)) }

                    case .noChoice:
                        NoChoiceView(isSubmitting: isSubmitting) { onSubmit(.noChoice) }
                }
            }
        } else if !challenge.hasStarted {
            StartEndBadge(kind: .startsAt, date: challenge.startDate)
        } else {
            StartEndBadge(kind: .endedAt, date: challenge.endDate)
        }
    }
}

struct InfoButton: View {
    let challengeType: ChallengeType

    var body: some View {
        Button {
            Task {
                await ChallengeInfoPopup.makeChallengeInfoPopup(for: challengeType).present()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 30, height: 30)
                    .shadow(color: .green.opacity(0.6), radius: 12)

                Text("i")
                    .font(.custom("BaksoSapi", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FinalStatusView: View {
    let status: ChallengeResponseStatus?

    var body: some View {
        VStack(spacing: 8) {
            if let status {
                switch status {
                case .validated:
                    Text("Response validated ✅")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                case .invalidated:
                    Text("Response invalidated ❌")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                case .waiting:
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Final decision for the challenge"))
    }
}

struct StatusBadge: View {
    let status: ChallengeResponseStatus

    var body: some View {
        let (text, color): (String, Color) = {
            switch status {
            case .waiting: return ("Waiting", .yellow)
            case .validated: return ("Validated", .green)
            case .invalidated: return ("Invalidated", .red)
            }
        }()
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct StartEndBadge: View {
    enum Kind { case startsAt, endedAt }
    let kind: Kind
    let date: Date

    var body: some View {
        let (text, color): (String, Color) = {
            switch kind {
            case .startsAt:
                return ("Starts at \(date.formatted(.dateTime.day().month().hour().minute()))", .blue)
            case .endedAt:
                return ("Ended at \(date.formatted(.dateTime.day().month().hour().minute()))", .gray)
            }
        }()
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel(Text(text))
    }
}

#Preview {
    let challenge = Challenge.mock
    ChallengeTileView(
        store: Store(initialState: ChallengeTileFeature.State(id: challenge.id, challenge: challenge, cohouseId: "cohouse_preview", cohouseName: "Preview House"),
                     reducer: { ChallengeTileFeature() })
    )
}
