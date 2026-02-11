//
//  RegistrationTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 11/02/2026.
//

import SwiftUI

struct RegistrationTileView: View {

    // MARK: - Properties

    let registrationDeadline: Date?
    let isRegistrationOpen: Bool
    let isAlreadyRegistered: Bool

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.ckrMint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("CKR Registration")
                    .font(.custom("BaksoSapi", size: 26))
                    .fontWeight(.heavy)

                if isAlreadyRegistered {
                    Text("Registered!")
                        .font(.custom("BaksoSapi", size: 20))
                        .fontWeight(.heavy)
                } else if isRegistrationOpen, let deadline = registrationDeadline {
                    Text("Register before \(deadline.formatted(date: .long, time: .omitted))")
                        .font(.custom("BaksoSapi", size: 14))
                        .fontWeight(.light)
                        .textCase(.uppercase)

                    Text("Register your cohouse!")
                        .font(.custom("BaksoSapi", size: 20))
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text("Registrations closed")
                        .font(.custom("BaksoSapi", size: 16))
                        .fontWeight(.light)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .padding()
        }
        .frame(height: 150)
    }
}

#Preview("Registration open") {
    RegistrationTileView(
        registrationDeadline: Date.from(year: 2026, month: 09, day: 01, hour: 23),
        isRegistrationOpen: true,
        isAlreadyRegistered: false
    )
}

#Preview("Already registered") {
    RegistrationTileView(
        registrationDeadline: Date.from(year: 2026, month: 09, day: 01, hour: 23),
        isRegistrationOpen: true,
        isAlreadyRegistered: true
    )
}

#Preview("Registrations closed") {
    RegistrationTileView(
        registrationDeadline: Date.from(year: 2026, month: 08, day: 01, hour: 23),
        isRegistrationOpen: false,
        isAlreadyRegistered: false
    )
}
