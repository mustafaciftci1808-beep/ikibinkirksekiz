import SwiftUI
import SceneKit

// MARK: - SwiftUI wrapper
struct AirplaneGameView: View {
    @StateObject private var game = AirplaneSceneController()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SceneView(
                    scene: game.scene,
                    pointOfView: game.cameraNode,
                    options: [.allowsCameraControl],
                    delegate: game,
                    preferredFramesPerSecond: 60,
                    antialiasingMode: .multisampling4X
                )
                // The drag gesture maps the user's finger movement to the plane's X/Y target.
                // Translation is normalized by the view size to keep movement consistent.
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            game.updatePlaneTarget(
                                translation: value.translation,
                                viewSize: proxy.size
                            )
                        }
                        .onEnded { _ in
                            game.resetPlaneTarget()
                        }
                )
                .edgesIgnoringSafeArea(.all)

                VStack {
                    Text("Mesafe: \(Int(game.distanceTraveled)) m")
                        // Distance comes from the plane's Z position vs. its start.
                        // See AirplaneSceneController.renderer(_:updateAtTime:).
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                    Spacer()
                }

                if game.isGameOver {
                    GameOverOverlay(distance: Int(game.distanceTraveled)) {
                        game.restart()
                    }
                }
            }
        }
    }
}

// MARK: - Game over UI
private struct GameOverOverlay: View {
    let distance: Int
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Game Over")
                .font(.largeTitle.bold())
            Text("Toplam mesafe: \(distance) m")
            Button("Tekrar Oyna", action: onRestart)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .ignoresSafeArea()
    }
}

// MARK: - Scene management
final class AirplaneSceneController: NSObject, ObservableObject, SCNSceneRendererDelegate {
    // Published properties drive the SwiftUI overlay.
    @Published var distanceTraveled: Double = 0
    @Published var isGameOver: Bool = false

    let scene: SCNScene = SCNScene()
    let cameraNode: SCNNode = SCNNode()

    private let planeNode = SCNNode()
    private var planeTarget = SIMD2<Float>(0, 0)
    private var lastUpdate: TimeInterval = 0
    private var startZ: Float = 0
    private var forwardSpeed: Float = 6
    private var obstacleZ: Float = 15
    private var obstacles: [SCNNode] = []

    override init() {
        super.init()
        setupScene()
    }

    func updatePlaneTarget(translation: CGSize, viewSize: CGSize) {
        // Convert drag distance into a small X/Y offset so the plane responds smoothly.
        let normalizedX = Float(translation.width / viewSize.width) * 10
        let normalizedY = Float(-translation.height / viewSize.height) * 8
        planeTarget = SIMD2(normalizedX, normalizedY)
    }

    func resetPlaneTarget() {
        planeTarget = .zero
    }

    func restart() {
        forwardSpeed = 6
        isGameOver = false
        distanceTraveled = 0
        startZ = 0
        lastUpdate = 0

        planeNode.position = SCNVector3(0, 1.5, 0)
        cameraNode.position = SCNVector3(0, 3, -10)

        // Remove existing obstacles and start fresh.
        for obstacle in obstacles {
            obstacle.removeFromParentNode()
        }
        obstacles.removeAll()
        obstacleZ = 15
    }

    // MARK: Scene setup
    private func setupScene() {
        scene.background.contents = UIColor.systemTeal

        // Camera that follows the plane from behind.
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        cameraNode.position = SCNVector3(0, 3, -10)
        cameraNode.eulerAngles = SCNVector3(-0.2, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Ambient and directional lights for basic shading.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 1000
        directional.eulerAngles = SCNVector3(-.pi / 3, .pi / 4, 0)
        scene.rootNode.addChildNode(directional)

        // Simple ground.
        let ground = SCNFloor()
        ground.firstMaterial?.diffuse.contents = UIColor.systemGreen
        ground.reflectivity = 0
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(groundNode)

        // Plane model built from a few boxes.
        let body = SCNBox(width: 1.0, height: 0.4, length: 1.6, chamferRadius: 0.1)
        body.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let wing = SCNBox(width: 1.6, height: 0.1, length: 0.4, chamferRadius: 0.05)
        wing.firstMaterial?.diffuse.contents = UIColor.systemOrange

        let bodyNode = SCNNode(geometry: body)
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0, -0.1)

        planeNode.addChildNode(bodyNode)
        planeNode.addChildNode(wingNode)
        planeNode.position = SCNVector3(0, 1.5, 0)
        scene.rootNode.addChildNode(planeNode)

        startZ = planeNode.position.z
    }

    // MARK: Renderer delegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = time }
        let delta = Float(time - lastUpdate)
        lastUpdate = time

        guard delta > 0 else { return }
        guard !isGameOver else { return }

        // Move plane forward automatically along Z.
        planeNode.position.z += forwardSpeed * delta

        // Smoothly move toward the drag target on X/Y.
        let current = SIMD2<Float>(planeNode.position.x, planeNode.position.y)
        let lerped = simd_mix(current, planeTarget, SIMD2<Float>(repeating: 0.1))
        planeNode.position.x = lerped.x
        planeNode.position.y = max(0.5, lerped.y + 1.5) // keep above ground

        // Follow with the camera.
        cameraNode.position.z = planeNode.position.z - 10

        // Distance is derived from how far the plane moved on the Z axis.
        let traveled = planeNode.position.z - startZ
        DispatchQueue.main.async {
            self.distanceTraveled = Double(traveled)
        }

        // Periodically drop simple cylinder "trees" ahead of the plane.
        while planeNode.position.z + 60 > obstacleZ {
            spawnTree(z: obstacleZ)
            obstacleZ += 5
        }

        // Remove obstacles that are far behind.
        obstacles.removeAll { node in
            if node.position.z < planeNode.position.z - 20 {
                node.removeFromParentNode()
                return true
            }
            return false
        }

        checkCollisions()
    }

    // MARK: Obstacles
    private func spawnTree(z: Float) {
        let tree = SCNCylinder(radius: 0.5, height: 2.0)
        tree.firstMaterial?.diffuse.contents = UIColor.systemGreen
        let node = SCNNode(geometry: tree)
        node.position = SCNVector3(randomX(), 1.0, z)
        scene.rootNode.addChildNode(node)
        obstacles.append(node)
    }

    private func randomX() -> Float {
        Float.random(in: -6...6)
    }

    // MARK: Collision detection
    private func checkCollisions() {
        for obstacle in obstacles {
            // Simple sphere-based collision: compare centers and a small radius.
            let dx = planeNode.position.x - obstacle.position.x
            let dy = planeNode.position.y - obstacle.position.y
            let dz = planeNode.position.z - obstacle.position.z
            let distance = sqrt(dx * dx + dy * dy + dz * dz)

            if distance < 1.2 {
                // Stop forward motion and reveal the overlay.
                forwardSpeed = 0
                DispatchQueue.main.async {
                    self.isGameOver = true
                }
                return
            }
        }
    }
}

struct AirplaneGameView_Previews: PreviewProvider {
    static var previews: some View {
        AirplaneGameView()
    }
}
