//
//  CKRTextField.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

struct CKRTextField: View {
    var title: String
    @Binding var value: String
    var isSecure: Bool = false
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization?
    var submitLabel: SubmitLabel?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundStyle(.gray)
                .font(.system(size: 14))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                if isSecure {
                    SecureField("", text: $value)
                        .textContentType(textContentType)
                        .padding(.horizontal)
                        .focused($isFocused)
                        .applySubmitLabel(submitLabel)
                } else {
                    TextField("", text: $value)
                        .textContentType(textContentType)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .padding(.horizontal)
                        .focused($isFocused)
                        .applySubmitLabel(submitLabel)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
        .frame(height: 80)
    }
}

// MARK: - SubmitLabel Helper

private extension View {
    @ViewBuilder
    func applySubmitLabel(_ label: SubmitLabel?) -> some View {
        if let label {
            self.submitLabel(label)
        } else {
            self
        }
    }
}

#Preview {
    ZStack {
        CKRTextField(title: "Name", value: .constant("Julien"))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { Color.ckrSkyLight.ignoresSafeArea() }
}
