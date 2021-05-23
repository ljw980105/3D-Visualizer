//
//  ColorPickerCell.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 4/16/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import Foundation
import UIKit

class ColorPickerCell: UICollectionViewCell{
    @IBOutlet weak var colorView: UIView!
    var color: UIColor!{
        didSet{
            colorView.backgroundColor = color
            colorView.clipsToBounds = true
            colorView.layer.cornerRadius = 39.0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        colorView.layer.borderWidth = 0
        colorView.layer.borderColor = UIColor.clear.cgColor
    }
}
