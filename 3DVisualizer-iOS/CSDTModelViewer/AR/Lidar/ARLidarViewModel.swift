//
//  ARLidarViewModel.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 5/22/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import Foundation
import RealityKit
import ARKit

class ARLidarViewModel {
    
    init() {
        
    }
    
    class func configureARView(_ arView: ARView) {
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding) // shows the LIDAR Mesh
    }
    
    class func getARConfig() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        return config
    }
}
