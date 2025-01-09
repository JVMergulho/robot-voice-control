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
        
        let viewController = ARViewController()
        let view = viewController.arView
        
        context.coordinator.arView = view
        view?.session.delegate = context.coordinator
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Atualizações, se necessário
    }
    
    func makeCoordinator() -> Coordinator{
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate{
        weak var arView: ARView?
        var focusEntity: FocusEntity?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView else {return}
            print("Anchors added to the scene: ", anchors)
            self.focusEntity = FocusEntity(on: arView, style: .classic(color: .yellow))
        }
    }
    
}
