//
//  ChallengeTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI
import ComposableArchitecture

struct ChallengeTileView: View {
    @Shared var challenge: Challenge

    var body: some View {
        ZStack {
            Color.CKRBlue
            VStack(alignment: .center, spacing: 0) {
                HeaderView(
                    title: self.challenge.title,
                    startTime: self.challenge.startTimestamp.dateValue(),
                    endTime: self.challenge.endTimestamp.dateValue()
                )
                BodyView(description: self.challenge.body)
                    .padding(.vertical)

                ChallengeContentView(challenge: self.challenge)
            }
            .padding()
        }
        .cornerRadius(20)
        .padding()
        .frame(minWidth: UIScreen.main.bounds.width, maxHeight: .infinity)
    }
}

struct HeaderView: View {
    var title: String
    var startTime: Date
    var endTime: Date

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Button {

                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.large)
                }
            }
            .padding(.bottom)
            .background(Color.green)
            VStack(alignment: .center, spacing: 20){
                Text(self.title)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .center, spacing: 50) {
                    VStack(spacing: 5) {
                        Text("START")
                        Text(self.startTime.formatted(.dateTime.day().month(.defaultDigits).hour().minute()))
                    }

                    VStack(spacing: 5) {
                        Text("END")
                        Text(self.endTime.formatted(.dateTime.day().month(.defaultDigits).hour().minute()))
                    }
                }
            }
            .background(Color.red)
        }
    }
}

struct BodyView: View {
    var description: String

    var body: some View {
        Text(self.description)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.green)
    }
}

struct FooterView: View {
    var body: some View {
        Text("Footer")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yellow)
    }
}

#Preview {
    ChallengeTileView(challenge: Shared(.mock))
}

@ViewBuilder
func ChallengeContentView(challenge: Challenge) -> some View {
    switch challenge.type {
    case .picture:
        PictureChoiceView()
    case .multipleChoice:
        MultipleChoiceView(choices: .mock)
    case .singleAnswer:
        SingleChoiceView(answer: .constant(""))
    case .noChoice:
        NoChoiceView(text: "")
    }
}
