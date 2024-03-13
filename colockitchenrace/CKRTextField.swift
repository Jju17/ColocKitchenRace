//
//  CKRTextField.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

struct CKRTextField<Content: View>: View {
    @Binding var value: String
    var frame: CGFloat = 80
    
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
                TextField("", text: self.$value)
                    .padding(.horizontal)
            }
        }
        .frame(maxHeight: self.frame)
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
