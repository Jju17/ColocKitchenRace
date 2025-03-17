//
//  DateComponents+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

extension DateComponents {
    var formattedSeconds: String {
        return String(format: "%02d", self.second ?? 00)
    }

    var formattedMinutes: String {
        return String(format: "%02d", self.minute ?? 00)
    }

    var formattedHours: String {
        return String(format: "%02d", self.hour ?? 00)
    }

    var formattedDays: String {
        return String(format: "%02d", self.day ?? 00)
    }

    var formattedMonths: String {
        return String(format: "%02d", self.month ?? 00)
    }

    var formattedYear: String {
        return String(format: "%02d", self.year ?? 00)
    }
}
