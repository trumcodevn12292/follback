import SwiftUI

struct DialPicker<T: Hashable>: View {
    let items: [T]
    @Binding var selected: T?
    let display: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selected == item
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selected = item
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        }
                    } label: {
                        Text(display(item))
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .monospaced))
                            .foregroundColor(isSelected ? Color.filmBackground : Color.filmTertiary)
                            .frame(minWidth: 52)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .background(
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.filmAccent, Color.filmGold],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color.filmAccent.opacity(0.4), radius: 8, x: 0, y: 3)
                                    } else {
                                        Capsule()
                                            .fill(Color.filmSurfaceSecondary)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.filmBorder, lineWidth: 0.5)
                                            )
                                    }
                                }
                            )
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .frame(height: 48)
    }
}
