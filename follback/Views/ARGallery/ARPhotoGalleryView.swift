import SwiftUI
import Combine
import RealityKit
import ARKit

struct ARPhotoGalleryView: View {
    let images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ARPhotoGalleryModel()
    @State private var showSnapshotToast = false
    @State private var showHelp = true

    var body: some View {
        ZStack {
            ARViewContainer(model: model)
                .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    Button {
                        model.takeSnapshot { image in
                            if let image {
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                withAnimation(.spring(response: 0.4)) { showSnapshotToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.spring(response: 0.4)) { showSnapshotToast = false }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }

                    Button {
                        model.removeAllPhotos()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .opacity(model.placedIndices.isEmpty ? 0 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom strip
                VStack(spacing: 8) {
                    if showHelp && !images.isEmpty {
                        Text("Tap a photo to place it in AR")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onTapGesture {
                                withAnimation { showHelp = false }
                            }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    model.addPhoto(image, at: index)
                                    withAnimation { showHelp = false }
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(model.placedIndices.contains(index)
                                                    ? Color(hex: "#C8BAA8")
                                                    : Color.white.opacity(0.2),
                                                    lineWidth: model.placedIndices.contains(index) ? 2 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ).ignoresSafeArea()
                )
            }

            // Toast
            if showSnapshotToast {
                VStack {
                    Spacer().frame(height: 60)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved to Photos")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#2A2A2A")))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - AR Model

@MainActor
class ARPhotoGalleryModel: ObservableObject {
    @Published var placedIndices: Set<Int> = []

    weak var arView: ARView?
    private var entities: [Int: Entity] = [:]
    private var placedCount = 0
    private var lastPlacedIndex: Int?
    private var selectedEntity: Entity?

    func addPhoto(_ image: UIImage, at index: Int) {
        guard let arView = arView else { return }
        placedIndices.insert(index)

        let entity = createPhotoEntity(image: image)
        entity.generateCollisionShapes(recursive: true)
        arView.installGestures([.translation, .rotation, .scale], for: entity)

        // Position in front of camera
        let offset = Float(placedCount % 3 - 1) * 0.3
        let depth: Float = 0.6 + Float(placedCount / 3) * 0.15

        if let camera = arView.session.currentFrame?.camera {
            let t = camera.transform
            let forward = SIMD3<Float>(-t.columns.2.x, -t.columns.2.y, -t.columns.2.z)
            let up = SIMD3<Float>(t.columns.1.x, t.columns.1.y, t.columns.1.z)
            let right = SIMD3<Float>(t.columns.0.x, t.columns.0.y, t.columns.0.z)

            let pos = SIMD3<Float>(
                t.columns.3.x + forward.x * depth + right.x * offset,
                t.columns.3.y + forward.y * depth + up.y * 0.05 + offset * 0.05,
                t.columns.3.z + forward.z * depth + right.z * offset
            )

            let anchor = AnchorEntity(world: pos)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
        } else {
            let anchor = AnchorEntity(world: [Float(placedCount % 3 - 1) * 0.3, 0, -0.8])
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
        }

        entities[index] = entity
        lastPlacedIndex = index
        placedCount += 1
    }

    func snapToSurface(at location: CGPoint) {
        guard let arView = arView,
              let lastIdx = lastPlacedIndex,
              let lastEntity = entities[lastIdx] else { return }

        guard let raycast = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first else { return }

        guard let anchor = lastEntity.parent else { return }
        let targetTransform = Transform(matrix: raycast.worldTransform)
        anchor.move(to: targetTransform, relativeTo: nil, duration: 0.3)
    }

    func removeAllPhotos() {
        guard let arView = arView else { return }
        for (_, entity) in entities {
            entity.removeFromParent()
        }
        entities.removeAll()
        placedIndices.removeAll()
        placedCount = 0
    }

    func takeSnapshot(completion: @escaping (UIImage?) -> Void) {
        arView?.snapshot(saveToHDR: false) { image in
            completion(image)
        }
    }

    private func createPhotoEntity(image: UIImage) -> ModelEntity {
        let aspectRatio = Float(max(image.size.width / image.size.height, 0.1))
        let width: Float = 0.4
        let height = width / aspectRatio

        let mesh = MeshResource.generatePlane(width: width, height: height)
        let material = createMaterial(from: image)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        return entity
    }

    private func createMaterial(from image: UIImage) -> SimpleMaterial {
        var material = SimpleMaterial()
        if let cgImage = image.cgImage ?? image._cgImageFromCIImage() {
            if let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
                material.color = .init(texture: .init(texture))
            }
        }
        material.color.tint = .white
        return material
    }
}

// MARK: - ARView Container

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var model: ARPhotoGalleryModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        model.arView = arView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    class Coordinator: NSObject {
        let model: ARPhotoGalleryModel
        init(model: ARPhotoGalleryModel) { self.model = model }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = model.arView else { return }
            let location = recognizer.location(in: arView)

            if arView.entity(at: location) != nil {
                return
            }

            model.snapToSurface(at: location)
        }
    }
}

// MARK: - Helpers

private extension UIImage {
    func _cgImageFromCIImage() -> CGImage? {
        guard let ciImage = ciImage else { return nil }
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

private extension simd_float4x4 {
    var position: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
