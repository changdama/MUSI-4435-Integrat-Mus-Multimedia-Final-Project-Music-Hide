import UIKit
import RealityKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var messageLabel: MessageLabel!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    
    var multipeerSession: MultipeerSession?
    
    let coachingOverlay = ARCoachingOverlayView()
    
    // A dictionary to map MultiPeer IDs to ARSession ID's.
    // This is useful for keeping track of which peer created which ARAnchors.
    var peerSessionIDs = [MCPeerID: String]()
    
    var sessionIDObservation: NSKeyValueObservation?
    
    var configuration: ARWorldTrackingConfiguration?
    
    var placementChords: [Chord] = [.CMajor, .FMajor, .GMajor, .AMinor]
    var discoveredChordAnchors: [AnchorEntity] = []
    var currentPlacementChordIndex = 0
    var role: Role = .seeker

    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)

        arView.session.delegate = self

        // Turn off ARView's automatically-configured session
        // to create and set up your own configuration.
        arView.automaticallyConfigureSession = false
        
        configuration = ARWorldTrackingConfiguration()

        // Enable a collaborative session.
        configuration?.isCollaborationEnabled = true
        
        // Enable realistic reflections.
        configuration?.environmentTexturing = .automatic

        // Begin the session.
        arView.session.run(configuration!)
        
        // Use key-value observation to monitor your ARSession's identifier.
        sessionIDObservation = observe(\.arView.session.identifier, options: [.new]) { object, change in
            print("SessionID changed to: \(change.newValue!)")
            // Tell all other peers about your ARSession's changed ID, so
            // that they can keep track of which ARAnchors are yours.
            guard let multipeerSession = self.multipeerSession else { return }
            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
        }
        
        setupCoachingOverlay()
        
        // Start looking for other players via MultiPeerConnectivity.
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData, peerJoinedHandler:
                                            peerJoined, peerLeftHandler: peerLeft, peerDiscoveredHandler: peerDiscovered,
        joinedSessionHandler: handleJoinSession)
        
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
        
//        messageLabel.displayMessage("Tap the screen to place cubes.\nInvite others to launch this app to join you.", duration: 60.0)
        
        instructionLabel.layer.borderColor = UIColor.white.cgColor // Change UIColor.blue to the color you want
                
        // Set border width
        instructionLabel.layer.borderWidth = 2.0 // Change the width as needed
        
        // Set corner radius
        instructionLabel.layer.cornerRadius = 8.0
        instructionLabel.bounds = CGRectInset(instructionLabel.frame, 10.0, 10.0);
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 18.0)
        instructionLabel.lineBreakMode = .byWordWrapping
        instructionLabel.numberOfLines = 0
        
        messageLabel.layer.cornerRadius = 8.0
        messageLabel.bounds = CGRectInset(instructionLabel.frame, 10.0, 10.0);
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 18.0)
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: arView)
        
        // Attempt to find a 3D location on a horizontal surface underneath the user's touch location.
        if self.role == .hider {
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                // Add an ARAnchor at the touch location with a special name you check later in `session(_:didAdd:)`.
                if currentPlacementChordIndex < placementChords.count {
                    let currentChord = placementChords[currentPlacementChordIndex]
                    let anchor = ARAnchor(name: currentChord.rawValue, transform: firstResult.worldTransform)
                    arView.session.add(anchor: anchor)
                    currentPlacementChordIndex += 1
                    if currentPlacementChordIndex < placementChords.count {
                        instructionLabel.text = "Tap to place the \(placementChords[currentPlacementChordIndex].rawValue) chord"
                    } else {
                        instructionLabel.isHidden = true
                    }
                } else {
                    instructionLabel.isHidden = true
                }
            } else {
                messageLabel.displayMessage("Can't place object - no surface found.\nLook for flat surfaces.", duration: 2.0)
                print("Warning: Object placement failed.")
            }
        } else {
            if let curAnchors = arView.session.currentFrame?.anchors.filter({ anchor in
                placementChords.contains(where: { chord in
                    chord.rawValue == anchor.name
                })}), curAnchors.count > 0 {
                
                var minDistance: Float = 100000.0
                var nearestAnchor = curAnchors.first
                for anchor in curAnchors {
                    let positionA = anchor.transform.columns.3
                    if let positionB = arView.session.currentFrame?.camera.transform.columns.3 {
                        
                        // Calculate the distance between the two positions
                        let distance = simd_distance(positionA, positionB)
                        if distance < minDistance {
                            minDistance = distance
                            nearestAnchor = anchor
                        }
                        print("Distance from \(anchor.name!): \(distance)")
                    }
                }
                if minDistance < 3.0 {
                    let anchorEntity = AnchorEntity(anchor: nearestAnchor!)
                    let modelEntity = try! ModelEntity.load(named: "\(nearestAnchor!.name!).usdz", in: .main)
                    anchorEntity.addChild(modelEntity)
                    discoveredChordAnchors.append(anchorEntity)
                    arView.scene.addAnchor(anchorEntity)
                    messageLabel.displayMessage("You found \(nearestAnchor!.name!)!", duration: 2.0)
                } else {
                    messageLabel.displayMessage("There is no chord nearby", duration: 2.0)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                messageLabel.displayMessage("Established joint experience with a peer.")
                // ...
                let anchorEntity = AnchorEntity(anchor: participantAnchor)
                
                let coordinateSystem = MeshResource.generateCoordinateSystemAxes()
                anchorEntity.addChild(coordinateSystem)
                
                let color = participantAnchor.sessionIdentifier?.toRandomColor() ?? .white
                let coloredSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.03),
                                                materials: [SimpleMaterial(color: color, isMetallic: true)])
                anchorEntity.addChild(coloredSphere)
                
                arView.scene.addAnchor(anchorEntity)
            } else if placementChords.contains(where: { chord in
                chord.rawValue == anchor.name
            }) {
                // Create a cube at the location of the anchor.
                let boxLength: Float = 0.05
                // Color the cube based on the user that placed it.
                let color = anchor.sessionIdentifier?.toRandomColor() ?? .white
//                let coloredCube = ModelEntity(mesh: MeshResource.generateBox(size: boxLength),
//                                              materials: [SimpleMaterial(color: color, isMetallic: true)])
                let audioFilePath = "\(anchor.name!).wav"
                    
                    // Offset the cube by half its length to align its bottom with the real-world surface.
                    //                coloredCube.position = [0, boxLength / 2, 0]
                    
                    // Attach the cube to the ARAnchor via an AnchorEntity.
                    //   World origin -> ARAnchor -> AnchorEntity -> ModelEntity
                let anchorEntity = AnchorEntity(anchor: anchor)
                if role == .hider {
                    let modelEntity = try! ModelEntity.load(named: "\(anchor.name!).usdz", in: .main)
                    anchorEntity.addChild(modelEntity)
                }
                arView.scene.addAnchor(anchorEntity)
                do {
                    let resource = try AudioFileResource.load(named: audioFilePath, in: .main, inputMode: .spatial, loadingStrategy: .preload, shouldLoop: true)
                    let audioController = anchorEntity.prepareAudio(resource)
                    audioController.gain = 0.4
                    audioController.play()
                    print ("\(audioFilePath) Audio played")
                    
                    // If you want to start playing right away, you can replace lines 7-8 with line 11 below
                    // let audioController = entity.playAudio(resource)
                } catch {
                    print("Error loading audio file")
                }
            }
        }
    }
    
    /// - Tag: DidOutputCollaborationData
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        guard let multipeerSession = multipeerSession else { return }
        if !multipeerSession.connectedPeers.isEmpty {
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
            else { fatalError("Unexpectedly failed to encode collaboration data.") }
            // Use reliable mode if the data is critical, and unreliable mode if the data is optional.
            let dataIsCritical = data.priority == .critical
            multipeerSession.sendToAllPeers(encodedData, reliably: dataIsCritical)
        } else {
            print("Deferred sending collaboration to later because there are no peers.")
        }
    }

    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            arView.session.update(with: collaborationData)
            return
        }
        // ...
        let sessionIDCommandString = "SessionID:"
        if let commandString = String(data: data, encoding: .utf8), commandString.starts(with: sessionIDCommandString) {
            let newSessionID = String(commandString[commandString.index(commandString.startIndex,
                                                                     offsetBy: sessionIDCommandString.count)...])
            // If this peer was using a different session ID before, remove all its associated anchors.
            // This will remove the old participant anchor and its geometry from the scene.
            if let oldSessionID = peerSessionIDs[peer] {
                removeAllAnchorsOriginatingFromARSessionWithID(oldSessionID)
            }
            
            peerSessionIDs[peer] = newSessionID
        }
    }
    
    func peerDiscovered(_ peer: MCPeerID) -> Bool {
        guard let multipeerSession = multipeerSession else { return false }
        
        if multipeerSession.connectedPeers.count > 3 {
            // Do not accept more than four users in the experience.
            messageLabel.displayMessage("A fifth peer wants to join the experience.\nThis app is limited to four users.", duration: 6.0)
            return false
        } else {
            return true
        }
    }
    /// - Tag: PeerJoined
    func peerJoined(_ peer: MCPeerID) {
        messageLabel.displayMessage("""
            A peer wants to join the experience.
            Hold the phones next to each other.
            """, duration: 6.0)
        // Provide your session ID to the new user so they can keep track of your anchors.
        sendARSessionIDTo(peers: [peer])
    }
        
    func peerLeft(_ peer: MCPeerID) {
        messageLabel.displayMessage("A peer has left the shared experience.")
        
        // Remove all ARAnchors associated with the peer that just left the experience.
        if let sessionID = peerSessionIDs[peer] {
            removeAllAnchorsOriginatingFromARSessionWithID(sessionID)
            peerSessionIDs.removeValue(forKey: peer)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present the error that occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @IBAction func resetTracking() {
//        guard let configuration = arView.session.configuration else { print("A configuration is required"); return }
//        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        for anchor in discoveredChordAnchors {
            arView.scene.removeAnchor(anchor)
        }
    }
    
    func handleJoinSession() {
        self.role = .seeker
        print ("Set role to seeker")
        instructionLabel.text = "Tap to find chords around you"
    }
    
    override var prefersStatusBarHidden: Bool {
        // Request that iOS hide the status bar to improve immersiveness of the AR experience.
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        // Request that iOS hide the home indicator to improve immersiveness of the AR experience.
        return true
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String) {
        guard let frame = arView.session.currentFrame else { return }
        for anchor in frame.anchors {
            guard let anchorSessionID = anchor.sessionIdentifier else { continue }
            if anchorSessionID.uuidString == identifier {
                arView.session.remove(anchor: anchor)
            }
        }
    }
    
    private func sendARSessionIDTo(peers: [MCPeerID]) {
        guard let multipeerSession = multipeerSession else { return }
        let idString = arView.session.identifier.uuidString
        let command = "SessionID:" + idString
        if let commandData = command.data(using: .utf8) {
            multipeerSession.sendToPeers(commandData, reliably: true, peers: peers)
        }
    }
}
