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
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
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
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.CKRPurple)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Next Edition In")
                            .font(.system(size: 26))
                            .fontWeight(.heavy)
                        Spacer()
                    }
                    Text(self.nextKitchenRace.formatted(date: .long, time: .omitted))
                        .font(.system(size: 12))
                        .fontWeight(.light)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                

                VStack {
                    HStack {
                        Text("Days")
                        Spacer()
                        Text("\(self.countDownComponents.formattedDays)")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text("\(self.countDownComponents.formattedHours)")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(self.countDownComponents.formattedMinutes)")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Seconds")
                        Spacer()
                        Text("\(self.countDownComponents.formattedSeconds)")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(.white)
                .font(.system(size: 26))
                .fontWeight(.heavy)
            }
            .padding()
        }
        .frame(height: 230)
        .onAppear {
            let _ = self.timer
        }
    }
}

#Preview {
    CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 03, day: 23, hour: 18))
}
