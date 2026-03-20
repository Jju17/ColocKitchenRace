//
//  CKRButton.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

struct CKRButton: View {
    var titleKey: LocalizedStringKey
    var action: () -> Void

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    var body: some View {
        Button {
            self.action()
        } label: {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.ckrGoldLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: .gray, radius: 2, x: 3, y: 3)
                Text(self.titleKey)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                    .frame(maxHeight: 100)
            }
        }
    }
}

#Preview {
    ZStack {
        CKRButton("Sign up") {

        }
        .frame(width: 300, height: 90)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { Color.ckrSkyLight.ignoresSafeArea() }
}
