//
//  PlanningCardViews.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 17/02/2026.
//

import SwiftUI

// MARK: - Step Card (Apero / Diner)

struct PlanningStepCardView: View {
    let step: PlanningStep
    let style: StepStyle
    let timeFormatter: DateFormatter

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            bodyContent
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 16, y: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(style.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.custom("BaksoSapi", size: 22))
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                Text("\(timeFormatter.string(from: step.startTime)) - \(timeFormatter.string(from: step.endTime))")
                    .font(.custom("BaksoSapi", size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            PlanningRoleBadge(role: step.role)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color)
    }

    // MARK: - Body

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Role description
            if step.role == .host {
                Label {
                    Text("You're hosting **\(step.cohouseName)** at your place")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "house.fill")
                        .foregroundStyle(style.color)
                }
            } else {
                Label {
                    Text("You're going to **\(step.cohouseName)**'s place")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(style.color)
                }
            }

            Divider()

            // Address (tappable — dialog attached to this button)
            PlanningAddressButton(address: step.address, accentColor: style.color)

            // Phone numbers (tappable — each has its own dialog)
            if step.hostPhone != nil || step.visitorPhone != nil {
                PlanningPhoneRow(
                    hostPhone: step.hostPhone,
                    visitorPhone: step.visitorPhone,
                    accentColor: style.color
                )
            }

            Divider()

            // People count
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(style.color)
                Text("**\(step.totalPeople)** people\(dietaryText(step.dietarySummary))")
                    .font(.subheadline)
            }

            // Dietary badges
            if !step.dietarySummary.isEmpty {
                PlanningDietaryBadges(summary: step.dietarySummary, accentColor: style.color)
            }
        }
        .padding()
    }

    private func dietaryText(_ summary: [String: Int]) -> String {
        if summary.isEmpty { return "" }
        let items = summary.map { "\($0.value) \($0.key.lowercased())" }
        return " including \(items.joined(separator: ", "))"
    }
}

// MARK: - Party Card

struct PlanningPartyCardView: View {
    let party: PartyInfo
    let style: StepStyle
    let timeFormatter: DateFormatter

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            bodyContent
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 16, y: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(style.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(party.name.uppercased())
                    .font(.custom("BaksoSapi", size: 22))
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                Text("\(timeFormatter.string(from: party.startTime)) - \(timeFormatter.string(from: party.endTime))")
                    .font(.custom("BaksoSapi", size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color)
    }

    // MARK: - Body

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Address (tappable — dialog attached to this button)
            PlanningAddressButton(address: party.address, accentColor: style.color)

            if let note = party.note, !note.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(style.color)
                    Text(note)
                        .font(.subheadline)
                        .italic()
                }
            }

            // Bracelet warning banner
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.ckrGold)
                Text("No bracelet, no entry!")
                    .font(.custom("BaksoSapi", size: 14))
                    .fontWeight(.heavy)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ckrGoldLight.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
    }
}

// MARK: - Step Styling

enum StepStyle {
    case apero, diner, party

    var color: Color {
        switch self {
        case .apero:  return .ckrCoral
        case .diner:  return .ckrMint
        case .party:  return .ckrLavender
        }
    }

    var emoji: String {
        switch self {
        case .apero:  return "🍻"
        case .diner:  return "🍽️"
        case .party:  return "🎉"
        }
    }

    var title: String {
        switch self {
        case .apero:  return "APERITIF"
        case .diner:  return "DINNER"
        case .party:  return "PARTY"
        }
    }
}
