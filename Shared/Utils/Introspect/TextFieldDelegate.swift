//
//  TextFieldDelegate.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import UIKit

class TextFieldDelegate: NSObject, UITextFieldDelegate {

    var shouldReturn: (() -> Bool)?

    init(shouldReturn: (() -> Bool)? = nil) {
        self.shouldReturn = shouldReturn
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        shouldReturn?() ?? true
    }
}
