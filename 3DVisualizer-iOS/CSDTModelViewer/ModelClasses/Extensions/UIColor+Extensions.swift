//
//  UIColor+Extensions.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 5/1/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import UIKit

extension UIColor {
    class func rgb(r red: CGFloat, g green: CGFloat, b blue: CGFloat) -> UIColor {
        return UIColor(red: red/255, green: green/255, blue: blue/255, alpha: 1)
    }
    
    class var labelColor: UIColor {
        UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return .black
            default:
                return .white
            }
        }
    }
}

