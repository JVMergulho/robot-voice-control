//
//  ContentView.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 07/01/25.
//

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


// RealityKit ViewController
class ARViewController: UIViewController {
    
    private var arView: ARView!
    var robotEntity: ModelEntity?
    var moveToLocation: Transform = Transform()
    
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create ARView
        arView = ARView(frame: self.view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        startPlaneDetection()
        loadRobot()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        startSpeechRecognition()
    }
    
    //MARK: - Placement
    
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        let tapLocation = recognizer.location(in: arView)
        print("Toque realizado na posição: \(tapLocation)")

        // Perform a raycast
        let raycastResults = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let result = raycastResults.first,
           let robotEntity{
            let worldPos = result.worldTransform.translation
            print("Coordenada 3D do toque: \(worldPos)")
            
            placeObject(object: robotEntity, location: worldPos)
            
            move(direction: .forward)
                        
        } else {
            print("Nenhum plano detectado no local do toque.")
        }
    }
    
    func placeObject(object: ModelEntity, location: SIMD3<Float>){
        
        let anchor = AnchorEntity(world: location)
        anchor.addChild(object)
        arView.scene.addAnchor(anchor)
    }
    
    func startPlaneDetection(){
        arView.automaticallyConfigureSession = true
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        //arView.debugOptions = .showAnchorGeometry
    
        arView.session.run(configuration)
    }
    
    //MARK: - Move
    
    func move(direction: Direction){
        let moveDuration: Double = 5.0 // seconds
        
        switch direction{
            case .forward:
                moveToLocation.translation = (robotEntity?.transform.translation)! + simd_float3(x: 0, y:0, z: 20)
                robotEntity?.move(to: moveToLocation, relativeTo: robotEntity, duration: 5)
            
                walkingAnimation(duration: moveDuration)
            
            case .back:
                moveToLocation.translation = (robotEntity?.transform.translation)! + simd_float3(x: 0, y:0, z: -20)
                robotEntity?.move(to: moveToLocation, relativeTo: robotEntity, duration: 5)
            
                walkingAnimation(duration: moveDuration)
            case .left:
                let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x: 0, y: 1, z: 0))
                robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
            
            case .right:
                let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(-90), axis: SIMD3(x: 0, y: 1, z: 0))
                robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
        }
        
    }
    
    func walkingAnimation(duration: Double){
        //USDZ file
        if let robotAnimation = robotEntity?.availableAnimations.first {
            robotEntity?.playAnimation(robotAnimation.repeat(duration: duration), transitionDuration: 0.5, startsPaused: false)
        } else {
            print("No animation present")
        }
    }
    
    //MARK: - Utilities
    
    func removeAllObjects(){
        arView.scene.anchors.removeAll()
    }
    
    func loadRobot(){
        do {
            robotEntity = try Entity.loadModel(named: "robot")
        } catch let error {
            print("Não foi possível carregar o modelo: \(error)")
        }
        
    }
    
    //MARK: - Speech Recgnition
    
    func startSpeechRecognition(){
        // 1. Permission
        requestPermition()
        // 2. audio record
        startAudioRecording()
        
        // 3. recognition
        speechRecognition()
    }
    
    func requestPermition(){
        SFSpeechRecognizer.requestAuthorization{ status in
            switch status{
                case .authorized:
                    print("Authorized")
                case .notDetermined:
                    print("Waiting...")
                case .denied:
                    print("Denied")
                default:
                    print("Some error ocorred")
            }
        }
    }
    
    func startAudioRecording(){
        //Input node
        let node = audioEngine.inputNode
        let recordFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordFormat) { (buffer, _) in
            self.speechRequest.append(buffer)
        }
        
        //Audio engine start
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioEngine.prepare()
            try audioEngine.start()
        } catch let error {
            print("Audio session error: \(error)")
        }
    }
    
    func speechRecognition(){
        guard let speechRecognizer = SFSpeechRecognizer() else{
            print("Speech recognizer not available")
            return()
        }
        
        var count = 0
        speechTask = speechRecognizer.recognitionTask(with: speechRequest) { (result, error) in
            count = count + 1
            
            if(count == 1){
                guard let result else { return }
                let recognizedText = result.bestTranscription.segments.last
                
                if let recognizedText = recognizedText?.substring {
                    if let direction = Direction.stringToDirection(word: recognizedText) {
                        print("Recognized text: \(recognizedText)")
                        
                        self.move(direction: direction)
                    }
                }
            } else if(count >= 3){
                count = 0
            }
        }
    }
}

enum Direction: String, CaseIterable{
    case forward
    case back
    case left
    case right
    
    static func stringToDirection(word: String) -> Direction?{
        for direction in Direction.allCases{
            if direction.rawValue == word{
                return direction
            }
        }
        
        return nil
    }
}

// Helper to extract translation from a matrix
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3(x: columns.3.x, y: columns.3.y, z: columns.3.z)
    }
}

