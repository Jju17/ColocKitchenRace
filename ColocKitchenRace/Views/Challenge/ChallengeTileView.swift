//
//  ChallengeTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI
import ComposableArchitecture
import MijickPopups

struct ChallengeTileView: View {
    let challenge: Challenge
    let response: ChallengeResponse?
    let onStart: () -> Void
    let onSubmit: (Data?) -> Void

    @State private var selectedAnswer: Int? = nil
    @State private var imageData: Data? = nil
    @State private var isImagePickerPresented = false

    var body: some View {
        ZStack {
            Color.CKRRandom
            VStack(alignment: .center, spacing: 0) {
                HeaderView(
                    title: challenge.title,
                    startTime: challenge.startDate,
                    endTime: challenge.endDate
                )
                BodyView(description: challenge.body)
                    .padding(.vertical)
                ChallengeContentView(
                    challenge: challenge,
                    response: response,
                    selectedAnswer: $selectedAnswer,
                    imageData: $imageData,
                    isImagePickerPresented: $isImagePickerPresented,
                    onStart: onStart,
                    onSubmit: onSubmit
                )
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

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Button {
                    
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
                        imageData: imageData,
                        isImagePickerPresented: isImagePickerPresented,
                        onSubmit: onSubmit
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
    ChallengeTileView(
        challenge: .mock,
        response: nil,
        onStart: {},
        onSubmit: { _ in }
    )
}
