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
                    let watchEffect: Effect<Action> = .run { send in
                        for await status in responseClient.watchStatus(challengeId, cohouseId) {
                            await send(._statusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.statusWatcher, cancelInFlight: true)

                    // Auto-submit for noChoice challenges — no extra step needed
                    if case .noChoice = state.challenge.content {
                        state.isSubmitting = true
                        return .merge(watchEffect, submit(newResponse))
                    }

                    return watchEffect

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
                    description: "Ce challenge vaut \(points) point\(points > 1 ? "s" : ""). Complète-le pour les ajouter au score de ta coloc !",
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg)
    }
}

// MARK: - Countdown Badge

struct CountdownBadge: View {
    let endDate: Date
    var accentColor: Color = .ckrCoral
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if let text = countdownText {
            Button {
                Task {
                    await ChallengeInfoPopup(
                        symbol: "timer",
                        title: "Temps restant",
                        description: detailedCountdown,
                        accentColor: accentColor
                    ).present()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text(text)
                        .font(.custom("BaksoSapi", size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.25))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .onReceive(timer) { _ in now = Date() }
        }
    }

    private var countdownText: String? {
        let remaining = endDate.timeIntervalSince(now)
        guard remaining > 0 else { return nil }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var detailedCountdown: String {
        let remaining = endDate.timeIntervalSince(now)
        guard remaining > 0 else { return "Ce challenge est terminé." }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        let timeString: String
        if days > 0 {
            timeString = "\(days) jour\(days > 1 ? "s" : "") et \(hours) heure\(hours > 1 ? "s" : "")"
        } else if hours > 0 {
            timeString = "\(hours) heure\(hours > 1 ? "s" : "") et \(minutes) minute\(minutes > 1 ? "s" : "")"
        } else {
            timeString = "\(minutes) minute\(minutes > 1 ? "s" : "")"
        }

        return "Il reste \(timeString) pour compléter ce challenge. Dépêche-toi ! ⏳"
    }
}

// MARK: - Challenge Content View

struct ChallengeContentView: View {
    let challenge: Challenge
    let response: ChallengeResponse?
    @Binding var selectedAnswer: Int?
    let pictureStore: StoreOf<PictureChoiceFeature>
    let onStart: () -> Void
    let onSubmit: (ChallengeSubmitPayload) -> Void
    let isSubmitting: Bool

    var body: some View {
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
                                .fill(Color.ckrLavender)
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

                    case let .multipleChoice(mc):
                        MultipleChoiceView(choices: mc.choices, selectedIndex: $selectedAnswer, isSubmitting: isSubmitting) {
                            if let idx = selectedAnswer { onSubmit(.multipleChoice(idx)) }
                        }
                        if selectedAnswer == nil {
                            Text("Choose an answer, then confirm.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .singleAnswer:
                        SingleAnswerView(isSubmitting: isSubmitting) { text in onSubmit(.singleAnswer(text)) }

                    case .noChoice:
                        if !isSubmitting {
                            NoChoiceView(isSubmitting: isSubmitting) { onSubmit(.noChoice) }
                        }
                    }
                }
            } else if !challenge.hasStarted {
                StartEndBadge(kind: .startsAt, date: challenge.startDate)
            } else {
                StartEndBadge(kind: .endedAt, date: challenge.endDate)
            }
        }
    }
}

// MARK: - Waiting Review

struct WaitingReviewView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(.ckrGold)
            Text("En attente de validation")
                .font(.custom("BaksoSapi", size: 18))
                .fontWeight(.semibold)
            Text("Ta réponse a été envoyée ! L'admin va la valider bientôt.")
                .font(.custom("BaksoSapi", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Final Status

struct FinalStatusView: View {
    let status: ChallengeResponseStatus?

    var body: some View {
        VStack(spacing: 8) {
            switch status {
            case .validated:
                Text("Response validated ✅")
                    .font(.custom("BaksoSapi", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(.ckrMint)
            case .invalidated:
                Text("Response invalidated ❌")
                    .font(.custom("BaksoSapi", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Final decision for the challenge"))
    }
}

// MARK: - Start/End Badge

struct StartEndBadge: View {
    enum Kind { case startsAt, endedAt }
    let kind: Kind
    let date: Date

    var body: some View {
        let (text, color): (String, Color) = {
            switch kind {
            case .startsAt:
                return ("Starts at \(date.formatted(.dateTime.day().month().hour().minute()))", .ckrSky)
            case .endedAt:
                return ("Ended at \(date.formatted(.dateTime.day().month().hour().minute()))", .secondary)
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
                     reducer: { ChallengeTileFeature() }),
        colorIndex: 0
    )
}
