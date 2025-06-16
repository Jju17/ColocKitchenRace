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

    @ObservableState
    struct State: Equatable {
        var imageData: Data? = nil
        var isImagePickerPresented = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case submitTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                return .none
            }
        }
    }
}

struct PictureChoiceView: View {
    @Perception.Bindable var store: StoreOf<PictureChoiceFeature>

    var body: some View {
        VStack {
            Button("UPLOAD YOUR PHOTO") {
                store.isImagePickerPresented = true
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .foregroundColor(.blue)
            .cornerRadius(8)

            if store.imageData != nil {
                Button("SUBMIT") {
                    store.send(.submitTapped)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $store.isImagePickerPresented) {
            ImagePicker(selectedImageData: $store.imageData)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImageData = image.jpegData(compressionQuality: 0.1)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
