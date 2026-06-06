import SwiftUI

struct LLabOrderDetailView: View {
    let order: LLabOrder
    @State private var detailOrder: LLabOrder?
    @State private var isLoadingDetail = false
    @State private var loadPhase = 0

    private var displayOrder: LLabOrder { detailOrder ?? order }

    private let phases = 6

    private func stagger(_ index: Int) -> Animation {
        .spring(response: 0.48, dampingFraction: 0.82)
        .delay(Double(index) * 0.07)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isLoadingDetail {
                ProgressView()
                    .tint(Color.filmAccent)
                    .padding(.top, 60)
            }

            VStack(spacing: 20) {
                headerSection
                    .opacity(loadPhase >= 1 ? 1 : 0)
                    .scaleEffect(loadPhase >= 1 ? 1 : 0.92)
                    .animation(stagger(0), value: loadPhase)

                serviceSection
                    .opacity(loadPhase >= 2 ? 1 : 0)
                    .offset(y: loadPhase >= 2 ? 0 : 24)
                    .animation(stagger(1), value: loadPhase)

                noteSection
                    .opacity(loadPhase >= 3 ? 1 : 0)
                    .offset(y: loadPhase >= 3 ? 0 : 24)
                    .animation(stagger(2), value: loadPhase)

                paymentSection
                    .opacity(loadPhase >= 4 ? 1 : 0)
                    .offset(y: loadPhase >= 4 ? 0 : 24)
                    .animation(stagger(3), value: loadPhase)

                negativeSection
                    .opacity(loadPhase >= 5 ? 1 : 0)
                    .offset(y: loadPhase >= 5 ? 0 : 24)
                    .animation(stagger(4), value: loadPhase)

                itemsSection
                    .opacity(loadPhase >= 6 ? 1 : 0)
                    .offset(y: loadPhase >= 6 ? 0 : 24)
                    .animation(stagger(5), value: loadPhase)
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .refreshable {
            if let fresh = await LLabService.shared.fetchOrderDetail(id: displayOrder.id) {
                detailOrder = fresh
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationTitle(L("Order #%@", displayOrder.orderNumber))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoadingDetail = true
            detailOrder = await LLabService.shared.fetchOrderDetail(id: displayOrder.id)
            isLoadingDetail = false
        }
        .onAppear {
            Task {
                for i in 1...phases {
                    try? await Task.sleep(nanoseconds: UInt64(70_000_000))
                    await MainActor.run {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                            loadPhase = i
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L("ORDER #%@", displayOrder.orderNumber))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.filmText)
                Spacer()
                statusBadge(displayOrder.status)
            }

            HStack(spacing: 0) {
                if let date = displayOrder.createdAt {
                    Label(formatDateTime(date), systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                }
                Spacer()
            }

            if let updated = displayOrder.updatedAt {
                HStack(spacing: 0) {
                    Label(L("Updated %@", formatDateTime(updated)), systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmTertiary.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
        )
    }

    // MARK: - Service

    private var serviceSection: some View {
        let rows = buildRows(
            displayOrder.orderType.map { (L("Service"), $0.capitalized) },
            displayOrder.scanType.map { (L("Scan"), $0) },
            displayOrder.retrievalMethod.map { (L("Retrieval"), $0.capitalized) },
            displayOrder.scanner.map { (L("Scanner"), $0) },
            displayOrder.location.map { (L("Location"), $0) },
            displayOrder.deliveryMethod.map { (L("Delivery"), $0.capitalized) },
            displayOrder.deliveryAddress.map { (L("Address"), $0) },
            displayOrder.urgent == true ? (L("Urgent"), L("Yes")) : nil
        )
        return sectionRowsView(title: L("Service"), rows: rows)
    }

    // MARK: - Note

    private var noteSection: some View {
        Group {
            if let note = displayOrder.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Note").uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)

                    noteRow(label: L("Ghi chú"), value: note)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmSurface)
                        )
                }
            }
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        let rows = buildRows(
            displayOrder.totalPrice > 0 ? (L("Total"), formatVND(displayOrder.totalPrice)) : nil,
            displayOrder.discount.map { (L("Discount"), "-\(formatVND($0))") },
            displayOrder.totalPaid.map { (L("Paid"), formatVND($0)) },
            displayOrder.paymentStatus.map { (L("Payment Status"), $0.capitalized) },
            displayOrder.rewardPoints > 0 ? (L("Reward Points"), "+\(displayOrder.rewardPoints)") : nil
        )
        return sectionRowsView(title: L("Payment"), rows: rows)
    }

    // MARK: - Negative / 底片

    private var negativeSection: some View {
        let rows = buildRows(
            displayOrder.negativeStatus.map { (L("Status"), $0.capitalized) },
            displayOrder.filmReturn.map { (L("Film Return"), $0 ? L("Yes") : L("No")) },
            displayOrder.expiryDate.map { (L("Giữ đến ngày"), formatDateTime($0)) },
            displayOrder.doneAt.map { (L("Completed"), formatDateTime($0)) }
        )
        return sectionRowsView(title: L("Negative"), rows: rows)
    }

    // MARK: - Items

    private var itemsSection: some View {
        Group {
            if let items = displayOrder.orderItems, !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("ORDER ITEMS"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)

                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            orderItemRow(item)
                                .opacity(loadPhase >= phases ? 1 : 0)
                                .offset(x: loadPhase >= phases ? 0 : -12)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.84)
                                        .delay(Double(index) * 0.04 + 0.45),
                                    value: loadPhase
                                )
                            if index < items.count - 1 {
                                Divider().background(Color.filmBorder.opacity(0.3))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.filmSurface)
                    )
                }
            }
        }
    }

    private func orderItemRow(_ item: LLabOrderItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if let type = item.filmType {
                            Text(type)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.filmText)
                        }
                        if let size = item.filmSize {
                            Text(size)
                                .font(.system(size: 14))
                                .foregroundColor(Color.filmTertiary)
                        }
                    }

                    HStack(spacing: 10) {
                        Text(item.quantity > 1 ? L("%d rolls", item.quantity) : L("1 roll"))
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmSecondary)
                        if let hours = item.processingHours {
                            Text(L("~%dh", hours))
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary.opacity(0.7))
                        }
                        if let frame = item.frameCount {
                            Text(L("%d frames", frame))
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary.opacity(0.7))
                        }
                    }
                }

                Spacer()

                if item.done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                        .scaleEffect(loadPhase >= phases ? 1 : 0.3)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(0.55),
                            value: loadPhase
                        )
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
            }

            if let rolls = item.details, !rolls.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(rolls.enumerated()), id: \.element.id) { _, roll in
                        HStack(spacing: 8) {
                            if roll.error == true {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            }
                            if let name = roll.filmName?.name {
                                Text(name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.filmText)
                            }
                            if let note = roll.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.filmTertiary.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.leading, 4)
                    }
                }
            }

            HStack(spacing: 8) {
                if let svc = item.serviceType {
                    Text(svc.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.filmAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent.opacity(0.12))
                        )
                }
                if let scan = item.scanType {
                    Text(scan)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.filmSecondary.opacity(0.1))
                        )
                }
                if let price = item.unitPrice, price > 0 {
                    Text(formatVND(price))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                }

                if let opts = item.options {
                    ForEach(Array(opts.enumerated()), id: \.offset) { _, meta in
                        if let name = meta.filmOption?.name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.filmTertiary.opacity(0.08))
                                )
                        }
                    }
                }

                Spacer()
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmTertiary.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.filmTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func noteRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.filmTertiary)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color.filmText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor(status).opacity(0.15))
            )
            .scaleEffect(loadPhase >= 1 ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15), value: loadPhase)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "processing", "pending": return .orange
        case "done", "completed": return .green
        case "expired": return .red
        case "canceled", "cancelled": return .gray
        default: return Color.filmAccent
        }
    }

    // MARK: - Row Builder

    private func buildRows(_ items: (String, String)?...) -> [(String, String)] {
        items.compactMap { $0 }
    }

    private func sectionRowsView(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    infoRow(label: row.0, value: row.1)
                    if index < rows.count - 1 {
                        Divider().background(Color.filmBorder.opacity(0.3))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
    }

    private func formatDateTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            display.locale = appLocale()
            return display.string(from: date)
        }
        return iso
    }

    private func formatVND(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "\(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")₫"
    }
}
