import SwiftUI

struct PhotoShareCardView: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    private let cardWidth: CGFloat = 1080
    private let horizontalPadding: CGFloat = 48

    private var photoWidth: CGFloat { cardWidth - horizontalPadding * 2 }

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: photoWidth)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 48)

            Spacer(minLength: 0)

            infoSection
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 48)
        }
        .frame(width: cardWidth)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.bottom, 28)

            Text(roll.filmName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let camera = roll.camera {
                Text(camera.displayNameWithLens)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                if let ap = frame.apertureDisplay {
                    tag(ap)
                }
                if let ss = frame.shutterDisplay {
                    tag(ss)
                }
                if roll.iso > 0 {
                    tag("ISO \(roll.iso)")
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .padding(.top, 20)

            HStack(spacing: 12) {
                Text("#\(frame.number)")
                    .fontWeight(.semibold)
                if let date = frame.capturedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.45))
            .padding(.top, 8)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}
