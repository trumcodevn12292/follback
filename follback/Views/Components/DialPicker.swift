import SwiftUI

struct DialPicker<T: Hashable>: View {
    let items: [T]
    @Binding var selected: T?
    let display: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selected == item
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selected = item
                            let impact = UIImpactFeedbackGenerator(style: .rigid)
                            impact.impactOccurred()
                        }
                    } label: {
                        Text(display(item))
                            .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .monospaced))
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
                            .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
                            .frame(minWidth: 56)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(Color.filmAccent.opacity(0.15))
                                            .blur(radius: 4)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 44)
    }
}
