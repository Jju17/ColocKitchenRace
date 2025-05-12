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

    let nextKitchenRace: Date?

    // MARK: - Private properties

    private var timer: Timer {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.nowDate = Date()
        }
    }
    private var countDownComponents: DateComponents? {
        guard let nextKitchenRace = self.nextKitchenRace else { return nil }
        return Date.countdownDateComponents(from: self.nowDate, to: nextKitchenRace)
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
                    Group {
                        if let nextKitchenRace {
                            Text(nextKitchenRace.formatted(date: .long, time: .omitted))
                        } else {
                            Text("No next date provided")
                        }
                    }
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
                        Text("\(self.countDownComponents?.formattedDays ?? "00")")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text("\(self.countDownComponents?.formattedHours ?? "00")")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(self.countDownComponents?.formattedMinutes ?? "00")")
                    }
                    Spacer(minLength: 2)
                    HStack {
                        Text("Seconds")
                        Spacer()
                        Text("\(self.countDownComponents?.formattedSeconds ?? "00")")
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
    CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 09, day: 23, hour: 18))
}
