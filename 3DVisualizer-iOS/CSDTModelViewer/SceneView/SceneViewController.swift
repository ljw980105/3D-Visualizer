//
//  SceneViewController.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 2/1/18.
//  Copyright © 2018 Jing Wei Li. All rights reserved.
//

import UIKit
import SceneKit
import ModelIO
import SceneKit.ModelIO
import ARKit
import Combine

fileprivate enum Styles {
    static let sceneViewBackgroundColor: UIColor = .systemBackground
}

class SceneViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var intensitySlider: UISlider!
    @IBOutlet weak var modelLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var ARButton: UIButton!
    @IBOutlet weak var colorSegments: UISegmentedControl!
    var lightingControl: SCNNode!
    var wigwaam: SCNNode?
    var customURL = "None"
    var modelObject: MDLMesh!
    var modelNode: SCNNode!
    var modelAsset: MDLAsset = .init()
    var ARModelScale: Float = 0.07
    var ARRotationAxis: String = "X"
    var selectedColor: UIColor = UIColor.clear
    var intensityOrTemperature = true
    var isFromWeb = false
    var blobLink: URL? = nil
    var ARPlaneMode: String = "Horizontal"
    let viewModel = SceneViewModel()
    var disposeBag: [AnyCancellable] = []
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .default
    }
    
    var animationMode: animationSettings = .none{
        didSet{
            guard animationMode != oldValue else { return }
            wigwaam?.removeAllActions()
            switch animationMode {
            case .rotate:
                wigwaam?.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 4)))
            default: break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        modelLoadingIndicator.tintColor = UIColor.white
        modelLoadingIndicator.startAnimating()
        navigationController?.setNavigationBarHidden(true, animated: true)
        colorSegments.selectedSegmentIndex = -1
        SceneViewModel.loadInitialModel(customURL: customURL, isFromWeb: isFromWeb)
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
            .sink { [weak self] error in
                if case .failure(let err) = error {
                    let alertController = UIAlertController(title: "Error",
                                                            message: err.localizedDescription,
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    alertController.view.tintColor = customGreen()
                    self?.present(alertController, animated: true, completion: nil)
                    print(err.localizedDescription)
                }
                
                self?.modelLoadingIndicator?.stopAnimating()
                self?.modelLoadingIndicator?.isOpaque = true
            } receiveValue: { [weak self] mesh in
                let sceneResult = SceneViewModel.createScene(from: mesh)
                let scene = sceneResult.scene
                self?.sceneView.autoenablesDefaultLighting = true
                self?.sceneView.allowsCameraControl = true
                self?.sceneView.scene = scene
                self?.sceneView.backgroundColor = Styles.sceneViewBackgroundColor
                self?.modelNode = sceneResult.node
                self?.modelObject = mesh
                self?.lightingControl = sceneResult.lightingControl
                
                self?.wigwaam = scene.rootNode.childNodes.first
                self?.modelLoadingIndicator?.stopAnimating()
                self?.modelLoadingIndicator?.isOpaque = true
            }
            .store(in: &disposeBag)

            
        // hides the ar button if Augmented Reality is not supported on the device.
        if !ARWorldTrackingConfiguration.isSupported {
            ARButton.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ask the user to save / not save the 3d model on device
        navigationController?.setNavigationBarHidden(true, animated: true)
        if UserDefaults.standard.bool(forKey: "ThirdPartyLaunch") {
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
                // now save to file system
                let fileManager = FileManager.default
                do {
                    let directory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    let fileURL = directory.appendingPathComponent(fileName)
                    let modelData =  try Data(contentsOf: URL(string: self.customURL)!)
                    try modelData.write(to: fileURL)
                    overlayTextWithVisualEffect(using: "Success", on: self.view)
                } catch {
                    overlayTextWithVisualEffect(using: "\(error.localizedDescription)", on: self.view)
                }
            }
            saveAlert.view.tintColor = customGreen()
            saveAlert.addAction(dontSaveAction)
            saveAlert.addAction(saveAction)
            self.present(saveAlert, animated: true, completion: nil)
            UserDefaults.standard.set(false, forKey: "ThirdPartyLaunch")
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: UIApplication.shared,
            queue: .main
        ) { _ in
            if let blobs = self.blobLink { try? FileManager.default.removeItem(at: blobs) }
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UserDefaults.standard.bool(forKey: "AR3DTouch"){
            ARButton.sendActions(for: .touchUpInside)
        }
        UserDefaults.standard.set(false, forKey: "AR3DTouch")
    }
    
    // MARK: - IBActions
    
    @IBAction func changeModelColor(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            lightingControl.light?.color = UIColor.red
        case 1:
            lightingControl.light?.color = UIColor.orange
        case 2:
            lightingControl.light?.color = UIColor.green
        default:
            break
        }
    }
    
    @IBAction func changeLightIntensity(_ sender: UISlider) {
        if intensityOrTemperature {
            lightingControl.light?.intensity = CGFloat(sender.value)
        } else {
            lightingControl.light?.temperature = CGFloat(sender.value)
        }
    }
    
    @IBAction func changeLightLocation(_ sender: UITapGestureRecognizer) {
        let ctr = sender.location(in: sceneView)
        lightingControl.position = SCNVector3Make(Float(ctr.x), Float(ctr.y), 100)
    }
    
    @IBAction func exitSceneView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
        if let blobs = blobLink { try? FileManager.default.removeItem(at: blobs) }
    }
    
    @IBAction func updateSceneSettings(from segue:UIStoryboardSegue){
        if let settings = segue.source as? SceneSettingsTableViewController{
            modelNode.geometry?.firstMaterial?.blendMode = stringToBlendMode[settings.selectedBlendSetting]!
            lightingControl.light?.type = stringToLightType[settings.selectedLightSetting]!
            animationMode = settings.selectedAnimationSetting
            ARModelScale = settings.ARModelScale
            ARRotationAxis = settings.ARRotationAxis
            intensityOrTemperature = settings.IntensityOrTemp
            ARPlaneMode = settings.planeSettings
            if intensityOrTemperature{
                intensitySlider.maximumValue = 200000
                lightingControl.light?.intensity = CGFloat(intensitySlider.value)
            } else {
                intensitySlider.maximumValue = 2000
                lightingControl.light?.temperature = CGFloat(intensitySlider.value/100)
            }
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var destinationViewController = segue.destination
        if let navigationViewController = destinationViewController as? UINavigationController {
            destinationViewController = navigationViewController.visibleViewController ?? destinationViewController
        }
        if let dest = destinationViewController as? SceneSettingsTableViewController{
            dest.lightSettings = determineLightType(with: lightingControl.light!)
            dest.blendSettings = determineBlendMode(with: modelNode.geometry!.firstMaterial!.blendMode)
            dest.animationMode = animationMode
            dest.ARModelScale = ARModelScale
            dest.ARRotationAxis = ARRotationAxis
            dest.IntensityOrTemp = intensityOrTemperature
            dest.planeSettings = ARPlaneMode
        }
        if let dest = destinationViewController as? AugmentedRealityViewController{
            let ar = ARModel()
            ar.model = modelObject
            ar.lightSettings = determineLightType(with: lightingControl.light!)
            ar.blendSettings = determineBlendMode(with: modelNode.geometry!.firstMaterial!.blendMode)
            ar.animationSettings = animationMode
            ar.lightColor = lightingControl.light!.color as? UIColor
            ar.modelScale = ARModelScale
            ar.rotationAxis = ARRotationAxis
            ar.planeDirection = ARPlaneMode
            dest.ar = ar
        }
        if let dest = destinationViewController as? ColorPickerCollectionView{
            dest.selectedColor = lightingControl.light?.color as? UIColor
            if let ppc = segue.destination.popoverPresentationController{
                ppc.delegate = self
            }
        }
    }
    
    @IBAction func getColorFromPicker(with segue: UIStoryboardSegue){
        if(selectedColor != lightingControl.light?.color as! UIColor){
            colorSegments.selectedSegmentIndex = -1 // deselect the segment if different
        }
        lightingControl.light?.color = selectedColor
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override var previewActionItems: [UIPreviewActionItem]{
        return [UIPreviewAction(title: "View in AR", style: .default) { action, controller in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.viewARPeekDidDismiss, object: nil, userInfo: nil)
                UserDefaults.standard.set(self.customURL, forKey: "ARPeek")
                controller.dismiss(animated: true)
            }
        }]
    }
}
