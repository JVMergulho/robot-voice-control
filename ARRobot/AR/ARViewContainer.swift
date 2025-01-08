//
//  ARViewContainer.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 08/01/25.
//
import SwiftUI

// UIKit Integration
struct ARViewContainer: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Atualizações, se necessário
    }
}
