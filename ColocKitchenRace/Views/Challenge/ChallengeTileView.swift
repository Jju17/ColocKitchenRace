//
//  ChallengeTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI
import ComposableArchitecture
import MijickPopups

struct ChallengeTileFeature: Reducer {

    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        let challenge: Challenge
        var response: ChallengeResponse?
        var kind: ChallengeKind
        var imageData: Data?
        var selectedAnswer: Int?
    }

    enum Action: Equatable {
            case startTapped
            case delegate(Delegate)
            case picture(PictureChoiceFeature.Action)

            enum Delegate: Equatable {
                case responseSubmitted(ChallengeResponse)
            }
        }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .startTapped:
                    if state.response == nil {
                        state.response = ChallengeResponse(
                            id: UUID(),
                            challengeId: state.challenge.id,
                            cohouseId: "cohouse_alpha",
                            content: state.challenge.content.toResponseContent,
                            status: .waiting,
                            submissionDate: Date()
                        )
                    }
                    return .none

                case .delegate:
                    return .none
                case .picture:
                    return .none
            }
        }
    }
}

// MARK: - View Hook

enum ChallengeKind: Equatable {
    case picture(PictureChoiceFeature.State)
}

struct ChallengeTileView: View {
    @Perception.Bindable var store: StoreOf<ChallengeTileFeature>

    var body: some View {
        ZStack {
            Color.CKRRandom
            VStack(spacing: 16) {
                HeaderView(
                    title: store.challenge.title,
                    startTime: store.challenge.startDate,
                    endTime: store.challenge.endDate,
                    challengeType: store.challenge.content.type
                )

                BodyView(description: store.challenge.body)

                if store.challenge.isActive {
                    if store.response == nil {
                        Button("Start") {
                            store.send(.startTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        switch store.kind {
                            case .picture:
                                PictureChoiceView(
                                    store: store.scope(
                                        state: \.kind.picture,
                                        action: ChallengeTileFeature.Action.picture
                                    )
                                )
                        }
                    }
                } else {
                    Text("Challenge completed")
                        .foregroundStyle(.gray)
                }
            }
            .padding()
        }
        .cornerRadius(20)
        .padding()
        .frame(width: UIScreen.main.bounds.width)

    }
}

struct HeaderView: View {
    var title: String
    var startTime: Date
    var endTime: Date
    var challengeType: ChallengeType

    func makeChallengeInfoPopup() -> any CenterPopup {
        switch self.challengeType {
            case .picture:
                ChallengeInfoPopup(
                    symbol: "photo.artframe",
                    title: "Picture Challenge",
                    description: "Take your best shot to impress the jury between the screen, and don't forget to smile ! 😄"
                )
            case .multipleChoice:
                ChallengeInfoPopup(
                    symbol: "square.grid.3x3.bottomleft.filled",
                    title: "Multiple choice ",
                    description: "Choose the wright answer, you have only one chance, so don't waste it ! 🫣"
                )
            case .singleAnswer:
                ChallengeInfoPopup(
                    symbol: "bubble.and.pencil",
                    title: "Single Answer",
                    description: "Open answer. Answer it honneslty and wihtout cheating ! We are watching you. 👀"
                )
            case .noChoice:
                ChallengeInfoPopup(
                    symbol: "",
                    title: "No choice",
                    description: "No action needed here ! Just click the button when you are sure the challenge is done. This will be automatically vaidate if you accomplish the challenge."
                )
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Button {
                    Task {
                        await self.makeChallengeInfoPopup().present()
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
    imageData: Binding<Data?>,
    isImagePickerPresented: Binding<Bool>,
    onStart: @escaping () -> Void,
    onSubmit: @escaping (Data?) -> Void
) -> some View {
    VStack {
        if challenge.isActive {
            if response == nil {
                Button(action: {
                    onStart()
                }) {
                    Text("Start")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            } else {
                switch challenge.content {
                    case .picture:
                        PictureChoiceView(
                            store: store.scope(
                                state: \.pictureChoice,
                                action: ChallengeTileFeature.Action.pictureChoice
                            )
                        )
                    case .multipleChoice:
                        MultipleChoiceView(selectedAnswer: selectedAnswer, onSubmit: onSubmit)
                    case .singleAnswer:
                        SingleAnswerView(onSubmit: onSubmit)
                    case .noChoice:
                        NoChoiceView(onSubmit: onSubmit)
                }
            }
        } else {
            Text("Challenge completed")
                .foregroundColor(.gray)
        }
    }
    .padding()
}

#Preview {
    let challenge = Challenge.mock
    ChallengeTileView(
        store: Store(initialState: ChallengeTileFeature.State(id: challenge.id, challenge: challenge),
                     reducer: { ChallengeTileFeature() })
    )
}
