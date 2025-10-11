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
  // MARK: - Config
  static let maxBytes: Int = 3_000_000 // 3 MB

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
    case _finishProcessing(Result<Data, ImageProcessError>)
  }

  enum ImageProcessError: Error, Equatable {
    case compressFailed
    case tooLarge(Int)
    case unknown
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
        state.isProcessing = true
        state.error = nil
        // Compression as an async task
        return .run { send in
          if let data = ImagePipeline.jpegDataCompressed(from: uiImage, maxDimension: 2000, quality: 0.7) {
            if data.count > PictureChoiceFeature.maxBytes {
              await send(._finishProcessing(.failure(.tooLarge(data.count))))
            } else {
              await send(._finishProcessing(.success(data)))
            }
          } else {
            await send(._finishProcessing(.failure(.compressFailed)))
          }
        }

      case let ._finishProcessing(result):
        state.isProcessing = false
        switch result {
        case let .success(data):
          state.imageData = data
          state.error = nil
        case let .failure(err):
          state.imageData = nil
          switch err {
          case .compressFailed:
            state.error = "Unable to compress the image. Please try again."
          case let .tooLarge(bytes):
            state.error = "Image is too large (\(ImagePipeline.humanSize(bytes))). Limit: \(ImagePipeline.humanSize(Self.maxBytes))."
          case .unknown:
            state.error = "Unknown error."
          }
        }
        return .none
      }
    }
  }
}

struct PictureChoiceView: View {
  @Bindable var store: StoreOf<PictureChoiceFeature>

  var body: some View {
    VStack(spacing: 12) {
      Button {
        store.send(.pickTapped)
      } label: {
        Text(store.imageData == nil ? "Choose a picture" : "Redo picture")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.white)
          .foregroundStyle(.blue)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .accessibilityLabel(Text(store.imageData == nil ? "Choose a picture" : "Redo picture"))

      // Preview + size
      if let data = store.imageData, let uiImage = UIImage(data: data) {
        VStack(spacing: 8) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(Text("Preview of the selected photo"))

          Text("Size: \(ImagePipeline.humanSize(data.count))")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if store.isProcessing {
        ProgressView("Processing image…")
      }

      if let err = store.error {
        Text(err)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.top, 4)
      }
    }
    .confirmationDialog("Photo source", isPresented: $store.sourceSheetPresented, titleVisibility: .visible) {
      Button("Camera", systemImage: "camera") {
        store.send(.sourceChosen(.camera))
      }
      .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
      Button("Library", systemImage: "photo.on.rectangle") {
        store.send(.sourceChosen(.library))
      }
      Button("Cancel", role: .cancel) {}
    }
    .sheet(isPresented: $store.isImagePickerPresented) {
      ImagePicker(
        selected: { image in store.send(.imagePicked(image)) },
        source: store.source == .camera ? .camera : .photoLibrary
      )
    }
  }
}
