import SwiftUI
import SwiftData

// MARK: - Photo Drop Delegate

struct PhotoDropDelegate: DropDelegate {
    let frame: Frame
    let roll: Roll
    @Binding var draggedFrame: Frame?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggedFrame = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedFrame, dragged.id != frame.id else { return }
        let frames = (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
        guard let fromIndex = frames.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = frames.firstIndex(where: { $0.id == frame.id }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let numbers = frames.map { $0.number }
            var reordered = frames
            let moving = reordered.remove(at: fromIndex)
            reordered.insert(moving, at: toIndex)
            for (i, f) in reordered.enumerated() {
                f.number = numbers[i]
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
