//
//  ARViewController.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 08/01/25.
//

import RealityKit
import ARKit
import Speech

// RealityKit ViewController
class ARViewController: UIViewController {
    
    var arView: ARView!
    var robotEntity: ModelEntity?
    let robotAnchor = AnchorEntity(world: SIMD3(x: 0, y: 0, z: 0))
    let moveDuration: Double = 5.0 // seconds
    
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    
    init(arView: ARView) {
        self.arView = arView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure ARView
        arView.frame = self.view.bounds
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
            
            //create plane below the robot
            makeGround(location: worldPos)
            
            //place robot a little above the plane to make it fall
            let robotPosition = worldPos + SIMD3(x: 0, y: 1, z: 0)
            
            placeObject(object: robotEntity, location: robotPosition)
            
            //move(direction: .forward)
                        
        } else {
            print("Nenhum plano detectado no local do toque.")
        }
    }
    
    func makeGround(location: SIMD3<Float>){
        let planeMesh = MeshResource.generatePlane(width: 2, depth: 2)
        let material = SimpleMaterial(color: .init(white: 1.0, alpha: 0.1), isMetallic: false)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        planeEntity.physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static)
        planeEntity.collision = CollisionComponent(shapes: [.generateBox(width: 2, height: 0.001, depth: 2)], isStatic: true)
        
        let anchor = AnchorEntity(world: location)
        anchor.addChild(planeEntity)
        
        // Adiciona o anchorEntity à cena do ARView
        arView.scene.addAnchor(anchor)
    }
    
    func placeObject(object: ModelEntity, location: SIMD3<Float>){
        object.position = location
        
        if robotAnchor.children.isEmpty{
            robotAnchor.addChild(object)
            arView.scene.addAnchor(robotAnchor)
        }
    }
    
    func startPlaneDetection(){
        arView.automaticallyConfigureSession = true
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        //add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlay.goal = .horizontalPlane
        view.addSubview(coachingOverlay)
        
        //centralize coaching overlay
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
        ])
        
        arView.debugOptions = [.showAnchorOrigins, .showPhysics]
    
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
    
    func movieLinear(_ distance: Float, reverse: Bool = false) {
        guard let robotEntity else { return }

        var moveToLocation = Transform()
        moveToLocation.translation = robotEntity.transform.translation + simd_float3(x: 0, y: 0, z: distance)
        robotEntity.move(to: moveToLocation, relativeTo: robotEntity, duration: moveDuration, timingFunction: .linear)

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
            
            guard let robotEntity,
                  let robotSize = robotEntity.model?.mesh.bounds.extents else {
                
                print("Error while loading robot model")
                return
            }
            
            // Collision
            let robotMask = CollisionGroup.all.subtracting(CollisionGroups.robotGroup)
            let robotFilter = CollisionFilter(group: CollisionGroups.robotGroup, mask: robotMask)
                        
            let collisionShape = ShapeResource.generateBox(size: robotSize)
            //let collisionComponent = CollisionComponent(shapes: [collisionShape], filter: robotFilter)
            //robotEntity.components.set(collisionComponent)

            let physicsBody = PhysicsBodyComponent(massProperties: .init(shape: collisionShape, mass: 50),
                                                   material: .default,
                                                   mode: .dynamic)
            robotEntity.components.set(physicsBody)
            
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

struct CollisionGroups {
    static let robotGroup = CollisionGroup(rawValue: 1 << 0)
    static let sphereGroup = CollisionGroup(rawValue: 1 << 1)
}
