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
    let moveDuration: Double = 5.0 // seconds
    
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
        
        if let robotEntity{
            installGestures(on: robotEntity)
        }
        
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
        
        switch direction{
            case .forward:
                movieLinear(30)
            case .back:
                movieLinear(-30, reverse: true)
            case .left:
                rotateInDegrees(90)
            case .right:
                rotateInDegrees(-90)
        }
        
    }
    
    func movieLinear(_ distance: Float, reverse: Bool = false){
        
        var moveToLocation = Transform()
        moveToLocation.translation = (robotEntity?.transform.translation)! + simd_float3(x: 0, y:0, z: distance)
        robotEntity?.move(to: moveToLocation, relativeTo: robotEntity, duration: moveDuration, timingFunction: .linear)
        
        walkingAnimation(duration: moveDuration, reverse: reverse)
    }
    
    func rotateInDegrees(_ angle: Float, duration: TimeInterval = 2) {
        guard let robotEntity else { return }
        
        // Determinar a rotação final
        let rotationAngle = simd_quatf(angle: GLKMathDegreesToRadians(angle), axis: SIMD3(x: 0, y: 1, z: 0))
        
        var rotateToAngle = Transform()
        rotateToAngle.rotation = rotationAngle

        // Aplicar a animação à entidade
        robotEntity.move(to: rotateToAngle, relativeTo: robotEntity, duration: duration, timingFunction: .easeInOut)
    }

    
    func walkingAnimation(duration: Double, reverse: Bool = false){
        //USDZ file
        guard let robotEntity else {return}
        
        print(robotEntity.availableAnimations)
        
        if let robotAnimation = robotEntity.availableAnimations.first {
            
            var playerDefinition = robotAnimation.definition
            
            playerDefinition.speed = reverse ? -1 : 1
            
            let playerAnimation = try! AnimationResource.generate(with: playerDefinition)
            
            playAnimation(animation: playerAnimation, repeate: 2)
            
        } else {
            print("No animation present")
        }
    }
    
    func playAnimation(animation: AnimationResource, repeate: Int) {
        
        guard repeate > 0 else{return}
        
        let repeate = repeate - 1
        
        robotEntity?.playAnimation(
            animation,
            startsPaused: false
        )
        
        Timer.scheduledTimer(withTimeInterval: animation.definition.duration, repeats: false){ timer in
            self.playAnimation(animation: animation, repeate: repeate)
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
    
    func installGestures(on object: ModelEntity){
        object.generateCollisionShapes(recursive: true)
        arView.installGestures([.scale], for: object)
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
        
        speechTask = speechRecognizer.recognitionTask(with: speechRequest) { (result, error) in
            
            guard let result else { return }
            let recognizedText = result.bestTranscription.segments.last
            
            if let recognizedText = recognizedText?.substring {
                if let direction = Direction.stringToDirection(word: recognizedText) {
                    print("Recognized text: \(recognizedText)")
                    
                    self.move(direction: direction)
                }
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

