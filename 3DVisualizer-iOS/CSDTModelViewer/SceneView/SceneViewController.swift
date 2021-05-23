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

class SceneViewController: UIViewController {
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var intensitySlider: UISlider!
    @IBOutlet weak var modelLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var ARButton: UIButton!
    @IBOutlet weak var colorSegments: UISegmentedControl!
    var customURL = "None"
    var isFromWeb = false
    let viewModel = SceneViewModel()
    var disposeBag: [AnyCancellable] = []
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .default
    }
    
    var animationMode: AnimationSettings = .none{
        didSet{
            guard animationMode != oldValue else { return }
            viewModel.wigwaam?.removeAllActions()
            switch animationMode {
            case .rotate:
                viewModel.wigwaam?.runAction(
                    SCNAction.repeatForever(
                        SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 4)
                    )
                )
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
        viewModel.load(customURL: customURL, isFromWeb: isFromWeb)
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
            } receiveValue: { [weak self] result in
                self?.sceneView.autoenablesDefaultLighting = true
                self?.sceneView.allowsCameraControl = true
                self?.sceneView.scene = result.scene
                self?.sceneView.backgroundColor = Styles.sceneViewBackgroundColor
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
            let saveAlert = viewModel.getSaveFileAlert(
                customURL: customURL,
                started: {
                    UserDefaults.standard.set(false, forKey: "ThirdPartyLaunch")
                }, completion: { [weak self] str in
                    overlayTextWithVisualEffect(using: str, on: self?.view)
                })
            self.present(saveAlert, animated: true, completion: nil)
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: UIApplication.shared,
            queue: .main
        ) { _ in
            if let blobs = self.viewModel.blobLink {
                try? FileManager.default.removeItem(at: blobs)
            }
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
            viewModel.lightingControl.light?.color = UIColor.red
        case 1:
            viewModel.lightingControl.light?.color = UIColor.orange
        case 2:
            viewModel.lightingControl.light?.color = UIColor.green
        default:
            break
        }
    }
    
    @IBAction func changeLightIntensity(_ sender: UISlider) {
        if viewModel.intensityOrTemperature {
            viewModel.lightingControl.light?.intensity = CGFloat(sender.value)
        } else {
            viewModel.lightingControl.light?.temperature = CGFloat(sender.value)
        }
    }
    
    @IBAction func changeLightLocation(_ sender: UITapGestureRecognizer) {
        let ctr = sender.location(in: sceneView)
        viewModel.lightingControl.position = SCNVector3Make(Float(ctr.x), Float(ctr.y), 100)
    }
    
    @IBAction func exitSceneView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
        if let blobs = viewModel.blobLink { try? FileManager.default.removeItem(at: blobs) }
    }
    
    @IBAction func arButtonTapped(_ sender: UIButton) {
        let alert = viewModel.getARVCAlert { [weak self] button in
            switch button {
            case .custom(let text):
                if let animationMode = self?.animationMode,
                   let vc = self?.viewModel.getARVC(
                        animationSettings: animationMode,
                        useLidar: text == "LIDAR"
                   ) {
                    vc.modalPresentationStyle = .fullScreen
                    self?.present(vc, animated: true)
                }
            }
        }
        if let ppc = alert.popoverPresentationController {
            ppc.sourceView = view
            ppc.sourceRect = sender.frame
        }
        present(alert, animated: true)
    }
    
    
    @IBAction func updateSceneSettings(from segue:UIStoryboardSegue){
        if let settings = segue.source as? SceneSettingsTableViewController{
            viewModel.modelNode.geometry?.firstMaterial?.blendMode = stringToBlendMode[settings.selectedBlendSetting] ?? .add
            viewModel.lightingControl.light?.type = stringToLightType[settings.selectedLightSetting]!
            animationMode = settings.selectedAnimationSetting
            viewModel.ARModelScale = settings.ARModelScale
            viewModel.ARRotationAxis = settings.ARRotationAxis
            viewModel.intensityOrTemperature = settings.IntensityOrTemp
            viewModel.ARPlaneMode = settings.planeSettings
            if viewModel.intensityOrTemperature{
                intensitySlider.maximumValue = 200000
                viewModel.lightingControl.light?.intensity = CGFloat(intensitySlider.value)
            } else {
                intensitySlider.maximumValue = 2000
                viewModel.lightingControl.light?.temperature = CGFloat(intensitySlider.value/100)
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
            dest.lightSettings = viewModel.lightingControl.light?.stringForm
            dest.blendSettings = determineBlendMode(with: viewModel.modelNode.geometry?.firstMaterial?.blendMode ?? .add)
            dest.animationMode = animationMode
            dest.ARModelScale = viewModel.ARModelScale
            dest.ARRotationAxis = viewModel.ARRotationAxis
            dest.IntensityOrTemp = viewModel.intensityOrTemperature
            dest.planeSettings = viewModel.ARPlaneMode
        }
        if let dest = destinationViewController as? ColorPickerCollectionView{
            dest.selectedColor = viewModel.lightingControl.light?.color as? UIColor
            if let ppc = segue.destination.popoverPresentationController{
                ppc.delegate = self
            }
        }
    }
    
    @IBAction func getColorFromPicker(with segue: UIStoryboardSegue){
        if (viewModel.selectedColor
                != viewModel.lightingControl.light?.color as? UIColor ?? .red) {
            colorSegments.selectedSegmentIndex = -1 // deselect the segment if different
        }
        viewModel.lightingControl.light?.color = viewModel.selectedColor
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        return [UIPreviewAction(title: "View in AR", style: .default) { action, controller in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.viewARPeekDidDismiss, object: nil, userInfo: nil)
                UserDefaults.standard.set(self.customURL, forKey: "ARPeek")
                controller.dismiss(animated: true)
            }
        }]
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension SceneViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
