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
    let countdownStart: Date?

    // MARK: - Private properties

    private var timer: Timer {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.nowDate = Date()
        }
    }

    private var hasCountdownStarted: Bool {
        guard let countdownStart else { return false }
        return nowDate >= countdownStart
    }

    private var countDownComponents: DateComponents? {
        guard let nextKitchenRace = self.nextKitchenRace,
              nextKitchenRace > self.nowDate
        else { return nil }
        return Date.countdownDateComponents(from: self.nowDate, to: nextKitchenRace)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.CKRPurple)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasCountdownStarted {
                countdownContent
            } else {
                comingSoonContent
            }
        }
        .frame(height: 230)
        .onAppear {
            let _ = self.timer
        }
    }

    // MARK: - Countdown (visible after startCKRCountdown)

    private var countdownContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Next Edition In")
                        .font(.custom("BaksoSapi", size: 26))
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
                .font(.custom("BaksoSapi", size: 14))
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
            .font(.custom("BaksoSapi", size: 26))
            .fontWeight(.heavy)
        }
        .padding()
    }

    // MARK: - Coming Soon (before startCKRCountdown)

    private var comingSoonContent: some View {
        VStack(spacing: 8) {
            Text("Next Edition")
                .font(.custom("BaksoSapi", size: 26))
                .fontWeight(.heavy)
            Text("Coming Soon")
                .font(.custom("BaksoSapi", size: 38))
                .fontWeight(.heavy)
            Text("Stay tuned!")
                .font(.custom("BaksoSapi", size: 16))
                .fontWeight(.light)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .padding()
    }
}

#Preview("Countdown started") {
    CountdownTileView(
        nextKitchenRace: Date.from(year: 2026, month: 09, day: 23, hour: 18),
        countdownStart: Date.from(year: 2025, month: 01, day: 01, hour: 0)
    )
}

#Preview("Coming soon") {
    CountdownTileView(
        nextKitchenRace: Date.from(year: 2026, month: 09, day: 23, hour: 18),
        countdownStart: Date.from(year: 2027, month: 01, day: 01, hour: 0)
    )
}
