import SwiftUI
import Combine
import AVFoundation
import CoreMedia
import UIKit

// MARK: - Exposure math helpers

enum ExposureMath {
    static let apertures: [Double] = [1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22]
    static let shutterSeconds: [Double] = [
        1, 1.0/2, 1.0/4, 1.0/8, 1.0/15, 1.0/30, 1.0/60, 1.0/125,
        1.0/250, 1.0/500, 1.0/1000, 1.0/2000, 1.0/4000, 1.0/8000
    ]

    /// EV at ISO 100 for the scene, from the camera's auto-exposure readings.
    static func ev100(apertureN: Double, shutter: Double, iso: Double) -> Double {
        guard shutter > 0, iso > 0 else { return 0 }
        return log2((apertureN * apertureN) / shutter) - log2(iso / 100.0)
    }

    /// The "log2(N^2 / t)" target for a given film ISO.
    static func evForISO(ev100: Double, filmISO: Int) -> Double {
        ev100 + log2(Double(filmISO) / 100.0)
    }

    /// Required shutter (seconds) for an aperture at a given EV.
    static func shutter(forAperture N: Double, ev: Double) -> Double {
        (N * N) / pow(2.0, ev)
    }

    /// Nearest standard shutter speed to an arbitrary duration.
    static func nearestShutter(_ seconds: Double) -> Double {
        guard seconds > 0 else { return shutterSeconds.last ?? 1.0/4000 }
        return shutterSeconds.min(by: { abs(log2($0) - log2(seconds)) < abs(log2($1) - log2(seconds)) }) ?? seconds
    }

    static func shutterLabel(_ seconds: Double) -> String {
        if seconds >= 1 {
            return String(format: "%.0f\"", seconds)
        }
        let denom = Int((1.0 / seconds).rounded())
        return "1/\(denom)"
    }

    static func apertureLabel(_ n: Double) -> String {
        if n == n.rounded() {
            return String(format: "f/%.0f", n)
        }
        return String(format: "f/%.1f", n)
    }
}

// MARK: - Camera model

@MainActor
final class LightMeterCamera: NSObject, ObservableObject {
    @Published var authorized = false
    @Published var running = false
    @Published var iso: Double = 100
    @Published var shutter: Double = 1.0/60
    @Published var apertureN: Double = 2.0
    @Published var locked = false

    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "lightmeter.session")
    private var pollTimer: Timer?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authorized = granted
                    if granted { self.configureAndRun() }
                }
            }
        default:
            authorized = false
        }
    }

    private func configureAndRun() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            if self.session.inputs.isEmpty,
               let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.device = device
            }
            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }
            Task { @MainActor in
                self.running = true
                self.apertureN = Double(self.device?.lensAperture ?? 2.0)
                self.startPolling()
            }
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readExposure() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func readExposure() {
        guard let device = device else { return }
        let dur = device.exposureDuration
        let seconds = CMTimeGetSeconds(dur)
        if seconds.isFinite && seconds > 0 {
            shutter = seconds
        }
        let currentISO = Double(device.iso)
        if currentISO.isFinite && currentISO > 0 {
            iso = currentISO
        }
        apertureN = Double(device.lensAperture)
    }

    func toggleLock() {
        guard let device = device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.exposureMode == .locked {
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    Task { @MainActor in self.locked = false }
                } else {
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                    Task { @MainActor in self.locked = true }
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore lock failures.
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            Task { @MainActor in self.running = false }
        }
    }
}

// MARK: - Preview layer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Light Meter View

struct LightMeterView: View {
    let filmISO: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = LightMeterCamera()
    @State private var selectedAperture: Double = 8

    private var ev100: Double {
        ExposureMath.ev100(apertureN: camera.apertureN, shutter: camera.shutter, iso: camera.iso)
    }

    private var evForFilm: Double {
        ExposureMath.evForISO(ev100: ev100, filmISO: filmISO)
    }

    private var recommendedShutter: Double {
        ExposureMath.nearestShutter(ExposureMath.shutter(forAperture: selectedAperture, ev: evForFilm))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            .frame(width: 60, height: 60)
                    )

                VStack {
                    topBar
                    Spacer()
                    readoutPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            } else {
                permissionDenied
            }
        }
        .onAppear {
            camera.start()
            selectedAperture = 8
        }
        .onDisappear { camera.stop() }
    }

    @State private var showCalculator = false

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
            Spacer()
            Text("LIGHT METER")
                .font(.system(size: 14, weight: .black))
                .kerning(1.5)
                .foregroundColor(.white)
            Spacer()
            Button {
                showCalculator = true
            } label: {
                Image(systemName: "function")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
            Button {
                camera.toggleLock()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: camera.locked ? "lock.fill" : "lock.open")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(camera.locked ? .yellow : .white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
        }
        .sheet(isPresented: $showCalculator) {
            NavigationStack {
                ExposureCalculatorView()
            }
        }
    }

    private var readoutPanel: some View {
        VStack(spacing: 18) {
            // Big recommendation
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ExposureMath.apertureLabel(selectedAperture))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("·")
                    .font(.system(size: 32, weight: .bold))
                    .opacity(0.5)
                Text(ExposureMath.shutterLabel(recommendedShutter))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)

            // Measured info
            HStack(spacing: 18) {
                metricView(label: "ISO", value: "\(filmISO)")
                metricView(label: "EV (ISO100)", value: String(format: "%.1f", ev100))
                metricView(label: "Meas. ISO", value: "\(Int(camera.iso))")
            }

            // Aperture selector
            VStack(spacing: 8) {
                Text("APERTURE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .foregroundColor(.white.opacity(0.6))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExposureMath.apertures, id: \.self) { ap in
                            let isSel = ap == selectedAperture
                            Button {
                                selectedAperture = ap
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(ExposureMath.apertureLabel(ap))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isSel ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(isSel ? Color.white : Color.white.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    private func metricView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.none")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white.opacity(0.7))
            Text("Camera access needed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Enable camera access for FilmVault in Settings to use the light meter.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white))
            }
            Button("Close") { dismiss() }
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 4)
        }
    }
}
