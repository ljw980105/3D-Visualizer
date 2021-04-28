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
import Combine
import Alamofire

// converison to MVC in progress
class SceneViewModel: NSObject {
    var modelAsset: MDLAsset!
    var ARModelScale: Float = 0.07
    var ARRotationAxis: String = "X"
    var selectedColor: UIColor = UIColor.clear
    var IntensityOrTemperature = true
    var isFromWeb = false
    var blobLink: URL? = nil
    
    override init() {
        super.init()
    }
    
    static let unknownError = NSError(domain: "Unknown Error", code: 0)
    
    // MARK: - Scene Loading
    
    static func loadMeshFromAsset(_ asset: MDLAsset) -> Future<MDLMesh, Error> {
        Future { promise in
            if let object = asset.object(at: 0) as? MDLMesh { // valid model object from link
                promise(.success(object))
            } else {
                promise(.failure(NSError(domain: "Load failed", code: 0)))
            }
        }
    }
    
    static func createScene(from mesh: MDLMesh) -> SceneLoadingResult {
        let scene = SCNScene()
        
        let modelNode = SCNNode(mdlObject: mesh)
        modelNode.scale = SCNVector3Make(2, 2, 2)
        modelNode.geometry?.firstMaterial?.blendMode = .alpha
        
        scene.rootNode.addChildNode(modelNode)
        
        let lightingControl = SCNNode()
        lightingControl.light = SCNLight()
        lightingControl.light?.type = .omni
        lightingControl.light?.color = UIColor.white
        lightingControl.light?.intensity = 100000
        lightingControl.position = SCNVector3Make(0, 50, 50)
        scene.rootNode.addChildNode(lightingControl)
        
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 9
        camera.zNear = 0
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3Make(50, 50, 50)
        scene.rootNode.addChildNode(cameraNode)
        return .init(scene: scene, node: modelNode, lightingControl: lightingControl)
    }
    
    
    static func loadInitialModel(
        customURL: String,
        isFromWeb: Bool
    ) -> AnyPublisher<ModelLoadingResult, Error> {
        if isFromWeb && customURL != "None" {
            return downloadFile(at: customURL)
                .map { fileURL -> ModelLoadingResult in
                    .init(asset: MDLAsset(url: fileURL), arModelScale: 0.07, blob: nil, customURL: fileURL.absoluteString)
                }
                .eraseToAnyPublisher()
        }
        return Future<ModelLoadingResult, Error> { promise in
            do {
                if customURL.contains("blob") { // blob files require special handling
                    guard let fileURL = URL(string: customURL) else {
                        throw SceneViewModel.unknownError
                    }
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
                    promise(.success(.init(
                        asset: MDLAsset(url: convertedFileURL),
                        arModelScale: 0.002,
                        blob: convertedFileURL,
                        customURL: nil
                    )))
                } else if customURL != "None" {
                    var customURL2 = customURL
                    if !isFromWeb {
                        customURL2 = "file://\(customURL)"
                        guard let url = URL(string: customURL2) else {
                            throw SceneViewModel.unknownError
                        }
                        promise(.success(
                            .init(asset: MDLAsset(url: url), arModelScale: 0.07, blob: nil, customURL: customURL2)
                        ))
                    }
                } else {
                    promise(.success(.default))
                }
            } catch let error {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private static func downloadFile(at link: String) -> Future<URL, Error> {
        Future { promise in
            AF.download(link, headers: [:]).responseData { res in
                if let url = res.fileURL {
                    promise(.success(url))
                } else if let error = res.error {
                    promise(.failure(error))
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
    
    static var `default`: ModelLoadingResult {
        let url = Bundle.main.url(forResource: "Models/AnishinaabeArcs", withExtension: "stl")!
        return .init(asset: MDLAsset(url: url), arModelScale: 0.002, blob: nil, customURL: nil)
    }
}

struct SceneLoadingResult {
    let scene: SCNScene
    let node: SCNNode
    let lightingControl: SCNNode
}
