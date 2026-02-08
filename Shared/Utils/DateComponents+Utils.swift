//
//  DateComponents+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

extension DateComponents {
    var formattedSeconds: String {
        String(format: "%02d", self.second ?? 0)
    }

    var formattedMinutes: String {
        String(format: "%02d", self.minute ?? 0)
    }

    var formattedHours: String {
        String(format: "%02d", self.hour ?? 0)
    }

    var formattedDays: String {
        String(format: "%02d", self.day ?? 0)
    }

    var formattedMonths: String {
        String(format: "%02d", self.month ?? 0)
    }

    var formattedYear: String {
        String(format: "%02d", self.year ?? 0)
    }
}
