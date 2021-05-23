//
//  ColorPickerCollectionView.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 4/16/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import Foundation
import UIKit

class ColorPickerCollectionView: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource{
    let colors: [UIColor] = [
        UIColor.black,
        UIColor.blue,
        UIColor.brown,
        UIColor.cyan,
        UIColor.purple,
        UIColor.gray,UIColor.yellow,
        UIColor.darkGray,UIColor.magenta,
        .rgb(r: 250, g: 190, b:190),
        .rgb(r: 210, g: 245, b:60),
        .rgb(r: 230, g: 190, b:255),
        .rgb(r: 255, g: 250, b:200),
        .rgb(r: 255, g: 215, b:180)
    ]
    var selectedColor: UIColor!
    let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    var selectedIndexPath: IndexPath?
    
    @IBOutlet weak var colorsColelctionView: UICollectionView! {
        didSet{
            colorsColelctionView.dataSource = self
            colorsColelctionView.delegate = self
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "colorsCell", for: indexPath)
        if let colorCell = cell as? ColorPickerCell{
            colorCell.color = colors[indexPath.row]
            if indexPath == selectedIndexPath {
                colorCell.colorView.layer.borderWidth = 5.0
                colorCell.colorView.layer.borderColor = customGreen().cgColor
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath), let custom = cell as? ColorPickerCell{
            selectedColor = custom.color
            custom.colorView.layer.borderWidth = 5.0
            custom.colorView.layer.borderColor = customGreen().cgColor
            hapticGenerator.impactOccurred()
            selectedIndexPath = indexPath
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath), let custom = cell as? ColorPickerCell{
            custom.colorView.layer.borderWidth = 0
            custom.colorView.layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? SceneViewController{
            dest.viewModel.selectedColor = selectedColor
        }
    }
}
