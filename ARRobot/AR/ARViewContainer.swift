//
//  ARViewContainer.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 08/01/25.
//
import SwiftUI
import ARKit
import RealityKit
import FocusEntity

// UIKit Integration
struct ARViewContainer: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> ARViewController{
        
        let arView = ARView(frame: .zero)
        
         context.coordinator.view = arView
         arView.session.delegate = context.coordinator
        
        let viewController = ARViewController(arView: arView)
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Atualizações, se necessário
    }
    
    func makeCoordinator() -> Coordinator{
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate{
        weak var view: ARView?
        var focusEntity: FocusEntity?
                        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let view else {return}
            
            if focusEntity == nil{
                print("Anchors added to the scene: ", anchors)
                self.focusEntity = FocusEntity(on: view, style: .classic(color: .yellow))
            }
        }
    }
    
}
