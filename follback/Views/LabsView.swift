import SwiftUI
import PhotosUI

struct LabsView: View {
    @ObservedObject private var store = CustomLabStore.shared

    @State private var appeared = false
    @State private var showAddLab = false
    @State private var labToEdit: CustomLab?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image("AppIconSmall")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        Text("LABS")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Color.filmText)
                            .kerning(1.5)
                    }
                    Spacer()
                    Button {
                        showAddLab = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appeared)

                if store.labs.isEmpty {
                    emptyLabsState
                } else {
                    labList
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
            .sheet(isPresented: $showAddLab) {
                LabEditSheet()
            }
            .sheet(item: $labToEdit) { lab in
                LabEditSheet(existing: lab)
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var emptyLabsState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flask")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.filmTertiary.opacity(0.5))
            Text("No labs yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
            Text("Add the labs you use to track where each roll is developed")
                .font(.system(size: 14))
                .foregroundColor(Color.filmTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showAddLab = true
            } label: {
                Text("Add Lab")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmBackground)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.filmAccent))
            }
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    private var labList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(store.labs) { lab in
                    labCard(lab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func labCard(_ lab: CustomLab) -> some View {
        Button {
            labToEdit = lab
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                CustomLabAvatar(lab: lab, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lab.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmText)
                    if !lab.labDescription.isEmpty {
                        Text(lab.labDescription)
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.remove(lab)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } label: {
                Label("Delete Lab", systemImage: "trash")
            }
        }
    }
}

/// Circular avatar for a custom lab: photo if set, otherwise a colored initial.
struct CustomLabAvatar: View {
    let lab: CustomLab
    var size: CGFloat = 52

    var body: some View {
        if let data = lab.avatarImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let hash = abs(lab.name.hashValue) % colors.count
            Text(String(lab.name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(colors[hash]))
        }
    }
}

// MARK: - Add / Edit sheet

private struct LabEditSheet: View {
    var existing: CustomLab?

    @ObservedObject private var store = CustomLabStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var labDescription: String
    @State private var avatarData: Data?
    @State private var avatarItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    init(existing: CustomLab? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _labDescription = State(initialValue: existing?.labDescription ?? "")
        _avatarData = State(initialValue: existing?.avatarImageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Avatar
                    Button {
                        showPhotoPicker = true
                    } label: {
                        ZStack {
                            if let data = avatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.filmSurface)
                                    .frame(width: 96, height: 96)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 24, weight: .light))
                                            Text("Avatar")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(Color.filmTertiary)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .photosPicker(isPresented: $showPhotoPicker, selection: $avatarItem, matching: .images)

                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LAB NAME")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)
                        TextField("e.g. The Lab Saigon", text: $name)
                            .font(.system(size: 16))
                            .foregroundColor(Color.filmText)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.filmBorder, lineWidth: 0.5)
                                    )
                            )
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)
                        TextField("e.g. C-41 & B&W, scan included (optional)", text: $labDescription, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundColor(Color.filmText)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.filmBorder, lineWidth: 0.5)
                                    )
                            )
                    }

                    // Save
                    Button {
                        save()
                    } label: {
                        Text("Save Lab")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.filmBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.filmTertiary : Color.filmAccent)
                            )
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.plain)

                    if let existing {
                        Button(role: .destructive) {
                            store.remove(existing)
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            dismiss()
                        } label: {
                            Text("Delete Lab")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle(existing == nil ? L("Add Lab") : L("Edit Lab"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.filmAccent)
                }
            }
            .onChange(of: avatarItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing {
            var updated = existing
            updated.name = trimmed
            updated.labDescription = labDescription
            updated.avatarImageData = avatarData
            store.update(updated)
        } else {
            store.add(CustomLab(name: trimmed, labDescription: labDescription, avatarImageData: avatarData))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
