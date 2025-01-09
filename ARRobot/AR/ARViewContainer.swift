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
        
        let viewController = ARViewController(arView: arView)
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Atualizações, se necessário
    }

    
}
