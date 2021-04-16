//
//  SceneViewModel.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 4/12/18.
//  Copyright © 2018 Jing Wei Li. All rights reserved.
//

import Foundation
import SceneKit
import SceneKit.ModelIO
import UIKit

// converison to MVC in progress
class SceneViewModel: NSObject {
    var lightingControl: SCNNode!
    var wigwaam: SCNNode!
    var cameraNode: SCNNode!
    var customURL = "None"
    var modelObject: MDLMesh!
    var modelNode: SCNNode!
    var modelAsset: MDLAsset! {
        didSet {
            setUp()
        }
    }
    var ARModelScale: Float = 0.07
    var ARRotationAxis: String = "X"
    var selectedColor: UIColor = UIColor.clear
    var IntensityOrTemperature = true
    var isFromWeb = false
    var blobLink: URL? = nil
    
    override init() {
        super.init()
    }
    
    func setUp() {
    
    }
    
    func loadInitialModel(
        customURL: String,
        isFromWeb: Bool,
        completion: @escaping (ModelLoadingResult) -> Void
    ) throws {
        if customURL.contains("blob") { // blob files require special handling
            guard let fileURL = URL(string: customURL) else { return }
            let fileManager = FileManager.default
            let modelData =  try Data(contentsOf: fileURL)
            let directory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let fileName = fileURL.lastPathComponent
            try modelData.write(to: directory.appendingPathComponent(fileName).appendingPathExtension("stl"))
            let convertedFileURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
                .appendingPathComponent(fileName)
                .appendingPathExtension("stl")
            DispatchQueue.main.async {
                completion(
                    .init(
                        asset: MDLAsset(url: convertedFileURL),
                        arModelScale: 0.002,
                        blob: convertedFileURL,
                        customURL: nil
                    )
                )
            }
        } else if customURL != "None" {
            var customURL2 = customURL
            if !isFromWeb {
                customURL2 = "file://\(customURL)"
            }
            guard let url = URL(string: customURL) else {
                throw NSError(domain: "Unknown Error", code: 0)
            }
            completion(.init(asset: MDLAsset(url: url), arModelScale: 0.07, blob: nil, customURL: customURL2))
        } else {
            if let url = Bundle.main.url(forResource: "Models/AnishinaabeArcs", withExtension: "stl") {
                DispatchQueue.main.async {
                    completion(.init(asset: MDLAsset(url: url), arModelScale: 0.002, blob: nil, customURL: nil))
                }
            }
        }
    }
}

struct ModelLoadingResult {
    let asset: MDLAsset
    let arModelScale: Float
    let blob: URL?
    let customURL: String?
}
