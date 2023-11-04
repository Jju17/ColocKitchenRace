//
//  CountdownTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 04/11/2023.
//

import SwiftUI

struct CountdownTileView: View {

    // MARK: - States

    @State var nowDate: Date = Date()

    // MARK: - Properties

    let nextKitchenRace: Date

// MARK: - Private properties

    private var timer: Timer {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {_ in
            self.nowDate = Date()
        }
    }
    private var countDownComponents: DateComponents {
        return Date.countdownDateComponents(from: self.nowDate, to: self.nextKitchenRace)
    }

    init(nextKitchenRace: Date) {
        self.nextKitchenRace = nextKitchenRace
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Next Kitchen Race")
                    Spacer()
                }
                Text("In")
            }
            .frame(maxWidth: .infinity)
            .font(.system(size: 28))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.top, 30)
            .padding(.bottom, 5)
            .padding(.horizontal, 15)


            Spacer()

            VStack(alignment: .leading) {
                Text("Days \(self.countDownComponents.formattedDays)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("Hours \(self.countDownComponents.formattedHours)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("Minutes \(self.countDownComponents.formattedMinutes)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("Seconds \(self.countDownComponents.formattedSeconds)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.white)
            .font(.system(size: 45))
            .fontWeight(.heavy)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 15)
            .onAppear(perform: {
                _ = self.timer
            })

            Button(action: {}) {
                Label("Sign In", systemImage: "arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding()
    }
}

#Preview {
    CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 03, day: 23, hour: 18))
}
