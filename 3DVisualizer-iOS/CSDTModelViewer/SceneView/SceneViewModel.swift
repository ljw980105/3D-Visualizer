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
import ARKit

// converison to MVC in progress
class SceneViewModel: NSObject {
    var lightingControl: SCNNode = .init()
    var wigwaam: SCNNode?
    var customURL = "None"
    var modelObject: MDLMesh = .init()
    var modelNode: SCNNode = .init()
    var modelAsset: MDLAsset = .init()
    var ARModelScale: Float = 0.07
    var ARRotationAxis: String = "X"
    var selectedColor: UIColor = .clear
    var intensityOrTemperature = true
    var isFromWeb = false
    var blobLink: URL? = nil
    var ARPlaneMode: String = "Horizontal"
    var currentAlert: SimpleAlert?
    override init() {
        super.init()
    }
    
    static let unknownError = NSError(domain: "Unknown Error", code: 0)
    
    // MARK: - Scene Loading
    
    func load(customURL: String, isFromWeb: Bool) -> AnyPublisher<SceneLoadingResult, Error> {
        SceneViewModel
            .loadInitialModel(customURL: customURL, isFromWeb: isFromWeb)
            .flatMap { result -> Future<MDLMesh, Error> in
                self.modelAsset = result.asset
                self.ARModelScale = result.arModelScale
                self.blobLink = result.blob
                return SceneViewModel.loadMeshFromAsset(result.asset)
            }
            .catch { error -> Future<MDLMesh, Error> in
                print(error.localizedDescription)
                let result = ModelLoadingResult.default
                self.modelAsset = result.asset
                self.ARModelScale = result.arModelScale
                self.blobLink = result.blob
                return SceneViewModel.loadMeshFromAsset(result.asset)
            }
            .flatMap { [weak self] mesh -> Future<SceneLoadingResult, Error> in
                let sceneResult = SceneViewModel.createScene(from: mesh)
                let scene = sceneResult.scene
                self?.modelNode = sceneResult.node
                self?.modelObject = mesh
                self?.lightingControl = sceneResult.lightingControl
                self?.wigwaam = scene.rootNode.childNodes.first
                return Future { promise in
                    promise(.success(sceneResult))
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: Loading Helpers
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
            let ext = URL(string: customURL)?.pathExtension ?? "stl"
            return Networking.downloadFile(at: customURL, renameToExtension: ext)
                .map { fileURL -> ModelLoadingResult in
                    return .init(asset: MDLAsset(url: fileURL), arModelScale: 0.07, blob: nil, customURL: fileURL.absoluteString)
                }
                .eraseToAnyPublisher()
        }
        return Future<ModelLoadingResult, Error> { promise in
            do {
                // 2018 CSDT Servers has STL models in blob format
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
                    // Opening Downloaded STLs thru the app
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
    
    //MARK: - Files
    /// Write a file to the app's default document directory, with the file named by the given fileName
    static func writeFile(
        locatedAt source: String,
        named fileName: String
    ) throws {
        guard let sourceURL = URL(string: source) else {
            throw NSError(domain: "invalid soruce url", code: 0)
        }
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let fileURL = directory.appendingPathComponent(fileName)
        let modelData = try Data(contentsOf: sourceURL)
        try modelData.write(to: fileURL)
    }

    // MARK: - Routing
    func getSaveFileAlert(
        customURL: String,
        started: @escaping () -> Void,
        completion: @escaping (String) -> Void
    ) -> UIAlertController {
        let saveAlert = UIAlertController(
            title: "Save Model on Device?",
            message: """
            If so, enter the name of model in the text field, with no whitespaces.
            Make sure that the file name ends with extension .stl .
            """,
            preferredStyle: .alert
        )
        saveAlert.addTextField { textfield in
            textfield.text = ""
        }
        let dontSaveAction = UIAlertAction(title: "Don't Save", style: .cancel, handler: nil)
        let saveAction = UIAlertAction(title: "Save", style: .default){ _ in
            guard let fileName = saveAlert.textFields?.first?.text else { return }
            do {
                try SceneViewModel.writeFile(locatedAt: customURL, named: fileName)
                completion("Success")
            } catch let err {
                completion(err.localizedDescription)
            }
        }
        saveAlert.view.tintColor = customGreen()
        saveAlert.addAction(dontSaveAction)
        saveAlert.addAction(saveAction)
        started()
        return saveAlert
    }
    
    func getARVCAlert(tappped: @escaping (SimpleAlertButton) -> Void) -> UIAlertController {
        // LIDAR ----
        var alert = SimpleAlert()
            .addButton(.custom("Standard"))
            .setTitle("Use AR Technology:")
            .setStyle(.actionSheet)
            .handleButtonTapped(tappped)
        currentAlert = alert
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            alert = alert.addButton(.custom("LIDAR"))
        }
        return alert.alert
    }
    
    func getARVC(animationSettings: AnimationSettings, useLidar: Bool) -> UIViewController {
        // LIDAR
        if useLidar {
            return ARLidarViewController(viewModel: .init())
        }
        
        // standard
        let ar = ARModel()
        ar.model = modelObject
        ar.lightSettings = lightingControl.light?.stringForm
        ar.blendSettings = determineBlendMode(with: modelNode.geometry?.firstMaterial?.blendMode ?? .add)
        ar.animationSettings = animationSettings
        ar.lightColor = lightingControl.light?.color as? UIColor
        ar.modelScale = ARModelScale
        ar.rotationAxis = ARRotationAxis
        ar.planeDirection = ARPlaneMode
        return AugmentedRealityViewController.instantiate(viewModel: ar)
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
