//
//  ContentView.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 07/01/25.
//

//TODO: Fix Bugs
// 1- each time the robot falls from a higer place: the transformations are accumulating

import RealityKit
import ARKit
import SwiftUI
import Combine
import Speech

struct ContentView : View {

    var body: some View {
        let ARViewContainer = ARViewContainer()
        
        ARViewContainer
            .edgesIgnoringSafeArea(.all)
    }

}
