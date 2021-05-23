//
//  SimpleAlert.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 5/22/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import UIKit

enum SimpleAlertButton {
    case custom(String)
    
    var string: String {
        switch self {
        case .custom(let str):
            return str
        }
    }
}

class SimpleAlert {
    private var style: UIAlertController.Style = .alert
    private var title: String = ""
    private var message: String?
    private var buttons: [SimpleAlertButton] = []
    private var buttonTapped: (SimpleAlertButton) -> Void = { _ in }
    init() {}
    
    func addButton(_ button: SimpleAlertButton) -> SimpleAlert {
        buttons.append(button)
        return self
    }
    
    func setStyle(_ style: UIAlertController.Style) -> SimpleAlert {
        self.style = style
        return self
    }
    
    func setTitle(_ title: String) -> SimpleAlert {
        self.title = title
        return self
    }
    
    func setMessage(_ message: String?) -> SimpleAlert {
        self.message = message
        return self
    }
    
    func handleButtonTapped(_ tapped: @escaping (SimpleAlertButton) -> Void) -> SimpleAlert {
        self.buttonTapped = tapped
        return self
    }
    
    var alert: UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        for button in buttons {
            let action = UIAlertAction(title: button.string, style: .default) { [weak self] completedAction in
                if button.string == completedAction.title {
                    self?.buttonTapped(button)
                }
            }
            alert.addAction(action)
        }
        return alert
    }
    
}
