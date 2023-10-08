//
//  UserProfileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import SwiftUI

struct UserProfileView: View {
    @State var prenom: String = ""
    @State var name: String = ""
    @State var email: String = ""
    @State var phoneNumber: String = ""
    @State var foodIntolerences: String = ""
    @State var isContactUser: Bool = false
    @State var isSubscribeToNews: Bool = false

    var body: some View {
        Form {
            Section("Basic info") {
                TextField("Prenom", text: self.$prenom)
                TextField("Nom", text: self.$name)
                TextField("Email", text: self.$email)
                TextField("GSM", text: self.$phoneNumber)
            }

            Section("Food related") {
                TextField("Food intolerances", text: self.$foodIntolerences)
            }

            Section("CKR") {
                Toggle(isOn: self.$isContactUser) {
                    Text("Are you the contact person ?")
                }
                Toggle(isOn: self.$isSubscribeToNews) {
                    Text("Do you want to have news from CKR team ?")
                }
            }
        }
        .navigationBarTitle("Julien Rahier")
    }
}

#Preview {
    NavigationStack {
        UserProfileView()
    }
}
