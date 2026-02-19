//
//  ChallengeContentView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 18/07/2024.
//

import ComposableArchitecture
import SwiftUI

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
}
