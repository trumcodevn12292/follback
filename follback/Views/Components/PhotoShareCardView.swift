import SwiftUI

struct PhotoShareCardView: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    private let cardWidth: CGFloat = 1080
    private let horizontalPadding: CGFloat = 52
    private var photoWidth: CGFloat { cardWidth - horizontalPadding * 2 }

    var body: some View {
        VStack(spacing: 0) {
            photoSection

            Spacer(minLength: 0)

            infoSection
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 52)
        }
        .frame(width: cardWidth)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private var photoSection: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: photoWidth)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(.top, 52)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.bottom, 28)

            Text(roll.filmName)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let camera = roll.camera {
                Text(camera.displayNameWithLens)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                if let ap = frame.apertureDisplay {
                    pill(ap)
                }
                if let ss = frame.shutterDisplay {
                    pill(ss)
                }
                if roll.iso > 0 {
                    pill("ISO \(roll.iso)")
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .padding(.top, 22)

            if let loc = frame.locationName, !loc.isEmpty {
                infoRow(icon: "mappin", text: loc)
                    .padding(.top, 20)
            }

            if let lab = roll.labName, !lab.isEmpty {
                infoRow(icon: "flask", text: lab)
                    .padding(.top, 12)
            }

            HStack(spacing: 8) {
                Text("#\(frame.number)")
                    .fontWeight(.semibold)
                if let date = frame.capturedAt {
                    Text("· \(date.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.35))
            .padding(.top, 20)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}
