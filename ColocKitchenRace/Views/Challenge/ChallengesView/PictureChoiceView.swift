//
//  PictureChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct PictureChoiceFeature {

  // MARK: - State
  @ObservableState
  struct State: Equatable {
    var imageData: Data? = nil
    var isImagePickerPresented = false
    var isProcessing = false
    var error: String?
    var sourceSheetPresented = false
    var source: Source = .library

    enum Source: Equatable { case camera, library }
  }

  // MARK: - Action
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case pickTapped                    // opens the source action sheet
    case sourceChosen(State.Source)    // choose camera/library
    case imagePicked(UIImage)          // raw picker output (UIImage)
    case imageCleared                  // clears current selection
    case _finishProcessing(Data?)
  }

  // MARK: - Body
  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .pickTapped:
        state.sourceSheetPresented = true
        return .none

      case let .sourceChosen(source):
        state.sourceSheetPresented = false
        state.source = source
        state.isImagePickerPresented = true
        state.error = nil
        return .none

      case .imageCleared:
        state.imageData = nil
        state.error = nil
        return .none

      case let .imagePicked(uiImage):
        state.isImagePickerPresented = false
        state.isProcessing = true
        state.error = nil
        return .run { send in
          let data = ImagePipeline.compress(image: uiImage)
          await send(._finishProcessing(data))
        }

      case let ._finishProcessing(data):
        state.isProcessing = false
        if let data {
          state.imageData = data
          state.error = nil
        } else {
          state.imageData = nil
          state.error = "Unable to compress the image. Please try again."
        }
        return .none
      }
    }
  }
}

struct PictureChoiceView: View {
    @Bindable var store: StoreOf<PictureChoiceFeature>
    let onSubmit: (Data) -> Void
    let isSubmitting: Bool

    var body: some View {
        VStack(spacing: 20) {
            Button {
                store.send(.pickTapped)
            } label: {
                HStack {
                    Image(systemName: store.imageData == nil ? "camera.fill" : "arrow.clockwise")
                    Text(store.imageData == nil ? "Take or choose a photo" : "Change photo")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.blue)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            if let data = store.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.5), lineWidth: 4)
                    )
                    .shadow(radius: 8)

                HStack {
                    Image(systemName: "photo")
                    Text("Ready to submit · \(ImagePipeline.humanSize(data.count))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if store.isProcessing {
                ProgressView("Processing photo…")
                    .progressViewStyle(.circular)
            }

            if let err = store.error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            if store.imageData != nil {
                Button("SUBMIT PHOTO") {
                    if let data = store.imageData {
                        onSubmit(data)
                    }
                }
                .submitButton(isLoading: isSubmitting)
                .disabled(isSubmitting)
            }
        }
        .fullScreenCover(isPresented: $store.isImagePickerPresented) {
            ImagePicker(
                selected: { store.send(.imagePicked($0)) },
                cancelled: {
                    store.send(.binding(.set(\.isImagePickerPresented, false)))
                },
                source: store.source == .camera ? .camera : .photoLibrary
            )
            .ignoresSafeArea()
        }
        .confirmationDialog("Photo source", isPresented: $store.sourceSheetPresented) {
            Button("Camera") { store.send(.sourceChosen(.camera)) }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            Button("Library") { store.send(.sourceChosen(.library)) }
            Button("Cancel", role: .cancel) {}
        }
    }
}
