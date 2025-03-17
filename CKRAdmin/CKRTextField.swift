//
//  Untitled.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import SwiftUI

struct CKRTextField<Content: View>: View {
    @Binding var value: String
    var frame: CGFloat = 80
    var isSecure: Bool = false

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            self.content()
                .foregroundStyle(.gray)
                .font(.system(size: 14))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if isSecure {
                    SecureField("", text: $value)
                        .padding(.horizontal)
                } else {
                    TextField("", text: self.$value)
                        .padding(.horizontal)
                }
            }
        }
        .frame(height: self.frame)
    }
}

#Preview {
    ZStack {
        CKRTextField(value: .constant("Julien"), frame: 80) {
            Text("Name")
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { Color.CKRBlue.ignoresSafeArea() }
}


struct CKRTextFieldStyle: TextFieldStyle {
    var title: String
    var frame: CGFloat = 80

    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(self.title)
                .foregroundStyle(.gray)
                .font(.system(size: 14))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                configuration
                    .padding(.horizontal)
            }
        }
        .frame(height: self.frame)
    }
}
