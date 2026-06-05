import SwiftUI

struct PhotoShareCardView: View {
    let image: UIImage
    let coverImage: UIImage?
    let frame: Frame
    let roll: Roll

    private let cardWidth: CGFloat = 1080
    private let pad: CGFloat = 48
    private var photoW: CGFloat { cardWidth - pad * 2 }

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: photoW)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
                .padding(.top, pad)
                .overlay(alignment: .topTrailing) {
                    if let cover = coverImage {
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                            .padding(.trailing, pad + 12)
                            .padding(.top, pad + 12)
                    }
                }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.bottom, 28)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(roll.filmName)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let camera = roll.camera {
                            Text(camera.displayNameWithLens)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }

                    Spacer(minLength: 0)

                    if let cover = coverImage {
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }

                HStack(spacing: 10) {
                    if let ap = frame.apertureDisplay { pill(ap) }
                    if let ss = frame.shutterDisplay { pill(ss) }
                    if roll.iso > 0 { pill("ISO \(roll.iso)") }
                }
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .padding(.top, 22)

                if let loc = roll.locationName, !loc.isEmpty {
                    infoRow(icon: "mappin.circle.fill", text: loc)
                        .padding(.top, 20)
                }

                if let lab = roll.labName, !lab.isEmpty {
                    infoRow(icon: "flask.fill", text: lab)
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
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 20)
            }
            .padding(.horizontal, pad)
            .padding(.bottom, pad)
        }
        .frame(width: cardWidth)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white.opacity(0.8))
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}
