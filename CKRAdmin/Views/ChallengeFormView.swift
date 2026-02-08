//
//  ChallengeFormView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 11/05/2025.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ChallengeFormFeature {
    @ObservableState
    struct State {
        var wipChallenge: Challenge = .empty
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case updateChallengeContent(ChallengeContent)
        case updateMultipleChoiceChoices([String])
        case updateMultipleChoiceShuffleAnswers(Bool)
        case updateMultipleChoiceCorrectAnswerIndex(Int?)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .updateChallengeContent(let content):
                    state.wipChallenge.content = content
                    return .none
                case .updateMultipleChoiceChoices(let choices):
                    if case .multipleChoice(var content) = state.wipChallenge.content {
                        content.choices = choices
                        state.wipChallenge.content = .multipleChoice(content)
                    }
                    return .none
                case .updateMultipleChoiceShuffleAnswers(let shuffle):
                    if case .multipleChoice(var content) = state.wipChallenge.content {
                        content.shuffleAnswers = shuffle
                        state.wipChallenge.content = .multipleChoice(content)
                    }
                    return .none
                case .updateMultipleChoiceCorrectAnswerIndex(let index):
                    if case .multipleChoice(var content) = state.wipChallenge.content {
                        content.correctAnswerIndex = index
                        state.wipChallenge.content = .multipleChoice(content)
                    }
                    return .none
                case .binding:
                    return .none
            }
        }
    }
}

struct ChallengeFormView: View {
    @Bindable var store: StoreOf<ChallengeFormFeature>

    var body: some View {
        Form {
            TextField("Title", text: $store.wipChallenge.title)
            TextField("Body", text: $store.wipChallenge.body)
            DatePicker("Start Date", selection: $store.wipChallenge.startDate)
            DatePicker("End Date", selection: $store.wipChallenge.endDate)
            Picker("Select Type", selection: Binding(
                get: { ChallengeType.fromContent(store.wipChallenge.content) },
                set: { newType in
                    store.send(.updateChallengeContent(newType.toContent()))
                }
            )) {
                ForEach(ChallengeType.allCases) { challengeType in
                    Text(challengeType.label)
                        .tag(challengeType)
                }
            }
            .pickerStyle(.palette)

            switch store.wipChallenge.content {
                case .picture:
                    EmptyView()
                case .multipleChoice(let content):
                    ForEach(0..<content.choices.count, id: \.self) { index in
                        TextField("Choice \(index + 1)", text: Binding(
                            get: { content.choices[index] },
                            set: { newValue in
                                var newChoices = content.choices
                                newChoices[index] = newValue
                                store.send(.updateMultipleChoiceChoices(newChoices))
                            }
                        ))
                    }

                    Toggle("Shuffle answers", isOn: Binding(
                        get: { content.shuffleAnswers },
                        set: { store.send(.updateMultipleChoiceShuffleAnswers($0)) }
                    ))

                    if !content.choices.isEmpty {
                        Picker("Correct answer", selection: Binding(
                            get: { content.correctAnswerIndex },
                            set: { store.send(.updateMultipleChoiceCorrectAnswerIndex($0)) }
                        )) {
                            Text("None").tag(Optional<Int>.none)
                            ForEach(0..<content.choices.count, id: \.self) { index in
                                Text(content.choices[index].isEmpty ? "Choice \(index + 1)" : content.choices[index])
                                    .tag(Optional(index))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                case .singleAnswer:
                    EmptyView()
                case .noChoice(var content):
                    TextField("Text", text: Binding(
                        get: { content.text },
                        set: {
                            content.text = $0
                            store.send(.updateChallengeContent(.noChoice(content)))
                        }
                    ))
            }
        }
    }
}

#Preview {
    ChallengeFormView(
        store: Store(initialState: ChallengeFormFeature.State()) {
            ChallengeFormFeature()
        }
    )
}
