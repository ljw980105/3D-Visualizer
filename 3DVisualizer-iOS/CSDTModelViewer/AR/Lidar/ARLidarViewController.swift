//
//  ARLidarViewController.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 5/22/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import UIKit
import ARKit
import RealityKit
import SnapKit

/// For devices supporting LIDAR
/// Tutorial: https://medium.com/macoclock/arkit-911-scene-reconstruction-with-a-lidar-scanner-57ff0a8b247e
class ARLidarViewController: UIViewController {
    let arView = ARView()
    let doneButton = UIButton()
    let viewModel: ARLidarViewModel
    
    init(viewModel: ARLidarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        configureConstraints()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    func configureConstraints() {
        view.addSubview(arView)
        arView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin)
        }
        
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        view.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin).offset(10)
        }
    }
    
    func setupAR() {
        ARLidarViewModel.configureARView(arView)
        arView.session.run(ARLidarViewModel.getARConfig(), options: [])
    }
    
    
    // MARK: LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = 1
        gesture.addTarget(self, action: #selector(handleRaycast(_:)))
        arView.addGestureRecognizer(gesture)
    }
    
    // MARK: Events
    
    @objc func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func handleRaycast(_ sender: UITapGestureRecognizer) {
        let tapLocation: CGPoint = sender.location(in: arView)
        let result = arView.raycast(
            from: tapLocation,
            allowing: .estimatedPlane,
            alignment: .any
        )
        guard let raycast: ARRaycastResult = result.first else { return }
        let anchor = AnchorEntity(world: raycast.worldTransform)
        anchor.addChild(Entity())
        arView.scene.anchors.append(anchor)
    }

}
