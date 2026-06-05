import SwiftUI

struct PhotoShareCardView: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 1350)
                .clipped()

            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .black.opacity(0.3),
                    .black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 540)

            VStack(alignment: .leading, spacing: 8) {
                Text(roll.filmName)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let camera = roll.camera {
                    Text(camera.displayNameWithLens)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(spacing: 16) {
                    if let ap = frame.apertureDisplay {
                        settingsTag(ap)
                    }
                    if let ss = frame.shutterDisplay {
                        settingsTag(ss)
                    }
                    if roll.iso > 0 {
                        settingsTag("ISO \(roll.iso)")
                    }
                }
                .font(.system(size: 18, weight: .semibold, design: .monospaced))

                HStack(spacing: 12) {
                    Text("#\(frame.number)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if let date = frame.capturedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 16, weight: .regular))
                    }
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(width: 1080, height: 1350)
        .background(Color.black)
    }

    private func settingsTag(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
