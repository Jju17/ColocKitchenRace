//
//  PlanningHelperViews.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 17/02/2026.
//

import SwiftUI

// MARK: - Role Badge

struct PlanningRoleBadge: View {
    let role: StepRole

    var body: some View {
        let (text, icon): (String, String) = switch role {
        case .host:    ("Hote", "house.fill")
        case .visitor: ("Invite", "figure.walk")
        }

        Label(text, systemImage: icon)
            .font(.custom("BaksoSapi", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

// MARK: - Address Button (self-contained with dialog)

struct PlanningAddressButton: View {
    let address: String
    let accentColor: Color

    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label {
                Text(address)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(accentColor)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Ouvrir l'adresse", isPresented: $showSheet) {
            Button("Apple Plans") {
                let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                URLOpener.open(urlString: "maps://?q=\(encoded)")
            }
            Button("Google Maps") {
                let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                URLOpener.open(urlString: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
            }
            Button("Copier l'adresse") {
                UIPasteboard.general.string = address
            }
            Button("Annuler", role: .cancel) {}
        }
    }
}

// MARK: - Phone Row

struct PlanningPhoneRow: View {
    let hostPhone: String?
    let visitorPhone: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hostPhone {
                PlanningPhoneButton(
                    label: "Tel. hote",
                    number: hostPhone,
                    accentColor: accentColor
                )
            }
            if let visitorPhone {
                PlanningPhoneButton(
                    label: "Tel. invite",
                    number: visitorPhone,
                    accentColor: accentColor
                )
            }
        }
    }
}

// MARK: - Phone Button (self-contained with dialog)

struct PlanningPhoneButton: View {
    let label: String
    let number: String
    let accentColor: Color

    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label {
                HStack(spacing: 4) {
                    Text("\(label) : ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(number)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(accentColor)
                }
            } icon: {
                Image(systemName: "phone.fill")
                    .foregroundStyle(accentColor)
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Appeler", isPresented: $showSheet) {
            Button("\(label) : \(number)") {
                let cleaned = number.replacingOccurrences(of: " ", with: "")
                URLOpener.open(urlString: "tel:\(cleaned)")
            }
            Button("Copier") {
                UIPasteboard.general.string = number
            }
            Button("Annuler", role: .cancel) {}
        }
    }
}

// MARK: - Dietary Badges

struct PlanningDietaryBadges: View {
    let summary: [String: Int]
    let accentColor: Color

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(summary.sorted(by: { $0.key < $1.key }), id: \.key) { key, count in
                HStack(spacing: 4) {
                    Image(systemName: dietaryIcon(for: key))
                        .font(.system(size: 10))
                    Text("\(count) \(key.lowercased())")
                        .font(.custom("BaksoSapi", size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.12))
                .foregroundStyle(accentColor)
                .clipShape(Capsule())
            }
        }
    }

    private func dietaryIcon(for restriction: String) -> String {
        let lower = restriction.lowercased()
        if lower.contains("vegetar") || lower.contains("vegan") { return "leaf.fill" }
        if lower.contains("gluten") { return "xmark.circle.fill" }
        if lower.contains("lactose") || lower.contains("lait") { return "drop.fill" }
        if lower.contains("halal") || lower.contains("casher") { return "star.fill" }
        return "fork.knife"
    }
}
