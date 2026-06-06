import SwiftUI

// MARK: - Exposure Calculator

struct ExposureCalculatorView: View {
    @State private var tab: Tab = .ev

    enum Tab: String, CaseIterable {
        case ev = "EV"
        case zone = "Zone"
        case reciprocity = "Reciprocity"

        var label: String {
            switch self {
            case .ev: return L("EV")
            case .zone: return L("Zone")
            case .reciprocity: return L("Reciprocity")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.label).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView(showsIndicators: false) {
                switch tab {
                case .ev: EVCalculatorView()
                case .zone: ZoneSystemView()
                case .reciprocity: ReciprocityView()
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationTitle(L("Exposure Calculator"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - EV Calculator

private struct EVCalculatorView: View {
    @State private var aperture = 5.6
    @State private var shutter = 1.0 / 125.0
    @State private var iso = 400.0

    private var ev: Double {
        ExposureMath.ev100(apertureN: aperture, shutter: shutter, iso: iso)
    }

    private var evRounded: Double { (ev * 100).rounded() / 100 }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                sliderRow(L("Aperture"), value: $aperture, range: 1.0...22, step: 0.1, label: ExposureMath.apertureLabel(aperture))
                sliderRow(L("Shutter"), value: $shutter, range: 1.0 / 8000...1.0, step: 0, label: ExposureMath.shutterLabel(shutter), logScale: true)
                sliderRow(L("ISO"), value: $iso, range: 25...6400, step: 1, label: "\(Int(iso))")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 8) {
                Text(L("Exposure Value (EV)"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(0.8)

                Text(evRounded >= 0 ? "+\(String(format: "%.1f", evRounded))" : String(format: "%.1f", evRounded))
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundColor(Color.filmAccent)

                Text(L("at ISO %d", Int(iso)))
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(L("EQUIVALENT PAIRS"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(0.8)

                VStack(spacing: 0) {
                    ForEach(Array(equivalentPairs().enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 12) {
                            Text(pair.aperture)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.filmText)
                                .frame(width: 60, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                                .foregroundColor(Color.filmTertiary)
                            Text(pair.shutter)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.filmText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider().background(Color.filmBorder.opacity(0.3))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
            }
        }
        .padding(16)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label text: String, logScale: Bool = false) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmTertiary)
                Spacer()
                Text(text)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.filmText)
            }

            if logScale {
                LogSlider(value: value, range: range)
                    .tint(Color.filmAccent)
            } else {
                Slider(value: value, in: range, step: step)
                    .tint(Color.filmAccent)
            }
        }
    }

    private func equivalentPairs() -> [(aperture: String, shutter: String)] {
        let baseShutters: [Double] = [1, 1.0/2, 1.0/4, 1.0/8, 1.0/15, 1.0/30, 1.0/60, 1.0/125, 1.0/250, 1.0/500, 1.0/1000, 1.0/2000]
        let baseApertures: [Double] = [1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22]
        var pairs: [(String, String)] = []

        for ap in baseApertures {
            let s = ExposureMath.shutter(forAperture: ap, ev: evRounded)
            let nearest = ExposureMath.nearestShutter(s)
            if nearest >= 1.0/8000, nearest <= 1 {
                pairs.append((ExposureMath.apertureLabel(ap), ExposureMath.shutterLabel(nearest)))
            }
        }
        return pairs
    }
}

// MARK: - Log Scale Slider

private struct LogSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private var logMin: Double { log10(range.lowerBound) }
    private var logMax: Double { log10(range.upperBound) }
    @State private var internalValue: Double = 0.5

    var body: some View {
        Slider(value: Binding(
            get: { (log10(value) - logMin) / (logMax - logMin) },
            set: { v in
                value = pow(10, logMin + v * (logMax - logMin))
                internalValue = v
            }
        ))
        .tint(Color.filmAccent)
    }
}

// MARK: - Zone System

private struct ZoneSystemView: View {
    @State private var selectedZone: Int = 5
    @State private var meterReadingEV: Double = 12
    @State private var filmISO: Double = 400

    private let zoneLabels = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    private var zoneExposureEV: Double {
        meterReadingEV + Double(selectedZone - 5)
    }

    private var zoneStops: String {
        let diff = selectedZone - 5
        if diff == 0 { return L("Meter reading") }
        return diff > 0
            ? L("+%d stop over (\u{2191} %@)", diff, zoneLabels[selectedZone])
            : L("%d stop under (\u{2193} %@)", diff, zoneLabels[selectedZone])
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text(L("Zone System"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)

                Text(L("Place your key tone on a zone, then adjust exposure accordingly."))
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(0..<11, id: \.self) { z in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedZone = z
                            }
                        } label: {
                            Text(zoneLabels[z])
                                .font(.system(size: 13, weight: selectedZone == z ? .bold : .medium))
                                .foregroundColor(selectedZone == z ? .white : Color.filmText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedZone == z ? Color.filmAccent : Color.filmSurface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 16) {
                row(label: L("Meter Reading (EV)"), value: Binding(
                    get: { "\(Int(meterReadingEV))" },
                    set: { if let v = Double($0) { meterReadingEV = v } }
                ))

                row(label: L("Film ISO"), value: Binding(
                    get: { "\(Int(filmISO))" },
                    set: { if let v = Double($0) { filmISO = v } }
                ))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 6) {
                Text(L("Selected Zone %@", zoneLabels[selectedZone]))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmText)

                Text(zoneStops)
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)

                Text(L("Target EV: %@", String(format: "%.1f", zoneExposureEV)))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.filmAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .padding(16)
    }

    private func row(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.filmTertiary)
            Spacer()
            TextField("", text: value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.filmText)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 80)
        }
    }
}

// MARK: - Reciprocity Failure

private struct ReciprocityView: View {
    @State private var measuredTime: Double = 1
    @State private var filmType: FilmTypeForReciprocity = .color

    enum FilmTypeForReciprocity: String, CaseIterable {
        case color = "Color"
        case bw = "B&W"
        case e6 = "E-6"

        var label: String {
            switch self {
            case .color: return L("Color Negative")
            case .bw: return L("B&W")
            case .e6: return L("E-6 (Slide)")
            }
        }
    }

    private var correctionFactor: Double {
        switch filmType {
        case .color:
            if measuredTime <= 0.001 { return 1 }
            if measuredTime <= 0.1 { return 1 }
            if measuredTime <= 1 { return 1 }
            if measuredTime <= 10 { return 2 }
            if measuredTime <= 100 { return 3 }
            return 4
        case .bw:
            if measuredTime <= 1 { return 1 }
            if measuredTime <= 10 { return measuredTime * 0.2 + 1 }
            if measuredTime <= 100 { return measuredTime * 0.1 + 2 }
            return measuredTime * 0.08 + 4
        case .e6:
            if measuredTime <= 0.001 { return 1 }
            if measuredTime <= 0.1 { return 1.3 }
            if measuredTime <= 1 { return 2 }
            if measuredTime <= 10 { return 4 }
            if measuredTime <= 100 { return 8 }
            return 16
        }
    }

    private var correctedTime: Double { measuredTime * correctionFactor }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text(L("Reciprocity Failure"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)

                Text(L("Long exposures need extra time since film doesn't react linearly to light."))
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 16) {
                HStack {
                    Text(L("Film Type"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.filmTertiary)
                    Spacer()
                    Picker("", selection: $filmType) {
                        ForEach(FilmTypeForReciprocity.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .tint(Color.filmAccent)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text(L("Metered Time"))
                            .font(.system(size: 14))
                            .foregroundColor(Color.filmTertiary)
                        Spacer()
                            Text(formatShutter(measuredTime))
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.filmText)
                    }

                    LogSlider(value: $measuredTime, range: 1.0/8000...120.0)
                        .tint(Color.filmAccent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            VStack(spacing: 12) {
                HStack {
                    Text(L("Metered"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.filmTertiary)
                    Spacer()
                    Text(formatShutter(measuredTime))
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color.filmText)
                }

                HStack {
                    Text(L("Factor"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.filmTertiary)
                    Spacer()
                    Text("\u{00D7}\(String(format: "%.1f", correctionFactor))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                }

                if correctionFactor != 1 {
                    Divider().background(Color.filmBorder.opacity(0.5))

                    HStack {
                        Text(L("Corrected Time"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        Text(formatShutter(correctedTime))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(Color.filmAccent)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .padding(16)
    }
}

// MARK: - Shutter Label

private func formatShutter(_ seconds: Double) -> String {
    if seconds >= 60 {
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        return s > 0 ? "\(m)m\(s)s" : "\(m)min"
    }
    if seconds >= 1 {
        return String(format: "%.0f\"", seconds.rounded())
    }
    let denom = Int((1.0 / seconds).rounded())
    return "1/\(denom)"
}
