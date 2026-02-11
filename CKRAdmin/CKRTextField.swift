//
//  CKRTextField.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/15/25.
//

import SwiftUI

struct CKRTextField: View {
    var title: String
    @Binding var value: String
    var isSecure: Bool = false

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
                        .padding(.horizontal)
                        .focused($isFocused)
                } else {
                    TextField("", text: $value)
                        .padding(.horizontal)
                        .focused($isFocused)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
        .frame(height: 80)
    }
}

#Preview {
    ZStack {
        CKRTextField(title: "Name", value: .constant("Julien"))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { Color.ckrSkyLight.ignoresSafeArea() }
}
