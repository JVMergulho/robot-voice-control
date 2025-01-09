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
        
        ZStack{
            ARViewContainer
                .edgesIgnoringSafeArea(.all)
            
            VStack{
                Spacer()
                Button(
                    action: {
                        NotificationCenter.default.post(name: .placeModel, object: nil)
                    print("Notificação enviada")
                },
                    label: {
                        Circle()
                            .foregroundStyle(.white)
                            .frame(width: 64)
                            .overlay(){
                                Image(.robotIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48)
                            }
                    }
                )
            }
            .padding(.bottom, 24)
        }

    }

}
