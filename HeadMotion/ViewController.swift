//
//  ViewController.swift
//  HeadMotion
//
//  Created by Vina Melody on 4/4/22.
//

import UIKit
import SceneKit
import CoreMotion
import simd

class ViewController: UIViewController {
    
    private let sceneView: SCNView = {
        let view = SCNView()
//        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let motionButton: UIButton = {
        let btn = UIButton(type: .system)
//        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let referenceButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Set Reference", for: .normal)
//        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let headingTitle: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.textAlignment = .center
//        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Forward"
        return label
    }()
    
    private var motionManager = CMHeadphoneMotionManager()
    private var headNode: SCNNode?
    private var referenceFrame = matrix_identity_float4x4

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        
        motionManager.delegate = self
        updateButtonState()
        
    }
    
    func setupViews() {
        guard let scene = SCNScene(named: "head.obj") else { return }
        headNode = scene.rootNode.childNodes.first
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(0, 0, 2.0)
        cameraNode.camera?.zNear = 0.05
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        sceneView.scene = scene
        sceneView.backgroundColor = .lightGray
        
        let buttonView = UIStackView(arrangedSubviews: [referenceButton, motionButton])
        buttonView.axis = .horizontal
        let subviews = [headingTitle, sceneView, buttonView]
        let stackView = UIStackView(arrangedSubviews: subviews)
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20.0),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20.0)
        ])
        
        referenceButton.addTarget(self, action: #selector(handleSetReference), for: .touchUpInside)
        motionButton.addTarget(self, action: #selector(toggleTracking), for: .touchUpInside)
    }
    
    func updateButtonState() {
        motionButton.isEnabled = motionManager.isDeviceMotionAvailable && CMHeadphoneMotionManager.authorizationStatus() != .denied
        
        let motionTitle = motionManager.isDeviceMotionActive ? "Stop Tracking" : "Start Tracking"
        motionButton.setTitle(motionTitle, for: .normal)
        
    }
    
    @objc func toggleTracking() {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .authorized:
            print("Motion is authorized")
        case .denied:
            print("User denied motion update access")
            return
        case .notDetermined:
            print("Permission for device motion tracking unknown; will prompt for access")
        default:
            break
        }
        
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        } else {
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] deviceMotion, error in
                if let self = self {
                    if let deviceMotion = deviceMotion {
                        self.handleMotion(self.motionManager, didUpdate: deviceMotion)
                    } else if let error = error {
                        self.handleMotionError(self.motionManager, didFail: error)
                    }
                }
            }
        }
        
        updateButtonState()
    }
    
    @objc func handleSetReference() {
        if let deviceMotion = motionManager.deviceMotion {
            referenceFrame = float4x4(rotationMatrix: deviceMotion.attitude.rotationMatrix).inverse
        }
    }


    func handleMotion(_ motionManager: CMHeadphoneMotionManager, didUpdate deviceMotion: CMDeviceMotion) {
        let rotation = float4x4(rotationMatrix: deviceMotion.attitude.rotationMatrix)
        let mirrorTransform = simd_float4x4([
            simd_float4(-1.0, 0.0, 0.0, 0.0),
            simd_float4(0.0, 1.0, 0.0, 0.0),
            simd_float4(0.0, 0.0, 1.0, 0.0),
            simd_float4(0.0, 0.0, 0.0, 1.0)
        ])
        
        headNode?.simdTransform = mirrorTransform * rotation * referenceFrame
        updateButtonState()
    }
    
    func handleMotionError(_ motionManager: CMHeadphoneMotionManager, didFail error: Error) {
        updateButtonState()
    }
}

extension ViewController: CMHeadphoneMotionManagerDelegate {
    
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        updateButtonState()
    }
    
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        updateButtonState()
    }
    
    
}

extension float4x4 {
    init(rotationMatrix r: CMRotationMatrix) {
        self.init([
            simd_float4(Float(-r.m11), Float(r.m13), Float(r.m12), 0.0),
            simd_float4(Float(-r.m31), Float(r.m33), Float(r.m32), 0.0),
            simd_float4(Float(-r.m21), Float(r.m23), Float(r.m22), 0.0),
            simd_float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
}
