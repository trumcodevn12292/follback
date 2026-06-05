import SwiftUI

struct LLabOrderTrackerView: View {
    @ObservedObject private var lLab = LLabService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignOutAlert = false
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var toastIsSuccess = true
    @State private var loginSuccess = false
    @FocusState private var focusedField: Field?
    @State private var pollingTask: Task<Void, Never>?

    private let pollInterval: TimeInterval = 30

    enum Field { case email, password }

    private var savedEmail: String? { lLab.getSavedEmail() }

    var body: some View {
        ZStack {
            Group {
                if lLab.isSignedIn {
                    signedInView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)).animation(.spring(response: 0.5, dampingFraction: 0.82)),
                            removal: .opacity.animation(.easeOut(duration: 0.2))
                        ))
                } else {
                    loginForm
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)).animation(.spring(response: 0.5, dampingFraction: 0.82)),
                            removal: .opacity.combined(with: .scale(scale: 0.96)).animation(.easeOut(duration: 0.2))
                        ))
                }
            }

            if showToast, let message = toastMessage {
                toastView(message: message, isSuccess: toastIsSuccess)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationTitle(L("LLab"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if lLab.isSignedIn {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSignOutAlert = true } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
        }
        .alert(L("Sign Out"), isPresented: $showSignOutAlert) {
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Sign Out"), role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    lLab.signOut()
                }
            }
        } message: {
            Text(L("You will be signed out of your LLab account."))
        }
        .onChange(of: lLab.isSignedIn) { _, signedIn in
            if signedIn {
                showSuccessToast()
                startPolling()
            } else {
                stopPolling()
            }
        }
        .onChange(of: lLab.error) { _, error in
            if let error {
                showErrorToast(error)
            }
        }
        .onAppear {
            if lLab.isSignedIn, let email = savedEmail {
                self.email = email
                startPolling()
            }
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Toast

    private func toastView(message: String, isSuccess: Bool) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isSuccess ? Color.filmSuccess : .red)
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.filmSurface.opacity(0.8)))
                    .overlay(Capsule().stroke(Color.filmBorder, lineWidth: 0.5))
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            .padding(.bottom, 100)
        }
    }

    private func showSuccessToast() {
        toastMessage = L("Signed in successfully")
        toastIsSuccess = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showToast = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    private func showErrorToast(_ message: String) {
        toastMessage = message
        toastIsSuccess = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showToast = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task { [weak lLab] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await lLab?.fetchOrders()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            VStack(spacing: 8) {
                Image("LLabLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(L("Sign in to LLab"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.filmText)

                Text(L("Track your film developing orders"))
                    .font(.system(size: 15))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(.bottom, 8)
            .transition(.opacity)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Email"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.filmSecondary)

                    TextField(L("your@email.com"), text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(14)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.filmSurfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.filmBorder, lineWidth: 0.5)
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Password"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.filmSecondary)

                    HStack(spacing: 0) {
                        if showPassword {
                            TextField(L("Password"), text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField(L("Password"), text: $password)
                                .textContentType(.password)
                        }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                    }
                    .padding(.leading, 14)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.filmSurfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.filmBorder, lineWidth: 0.5)
                            )
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                if lLab.isLoading {
                    ProgressView()
                        .tint(Color.filmAccent)
                        .scaleEffect(1.1)
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 10) {
                        Text(L("Sign In"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(canSubmit ? Color.filmAccent : Color.filmBorder)
                    )
                    .foregroundColor(.white)
                    .opacity(lLab.isLoading ? 0 : 1)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .scaleEffect(lLab.isLoading ? 0.95 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lLab.isLoading)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: canSubmit)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && !password.isEmpty
        && !lLab.isLoading
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            lLab.error = nil
        }
        Task {
            await lLab.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        }
    }

    // MARK: - Signed In View

    private var signedInView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                userHeader
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1)),
                        removal: .opacity
                    ))
                ordersSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)).animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.15)),
                        removal: .opacity
                    ))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .refreshable {
            await lLab.fetchOrders()
        }
    }

    private var userHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.filmAccent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(lLab.user?.fullName ?? "")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.filmText)
                    Text(lLab.user?.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(Color.filmTertiary)
                }

                Spacer()
            }

            HStack(spacing: 20) {
                statBadge(value: "\(lLab.user?.rewardPoints ?? 0)", label: L("Points"))
                statBadge(value: "\(lLab.orders.count)", label: L("Orders"))
            }
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.filmText)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.filmTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.filmSurface)
        )
    }

    // MARK: - Orders Section

    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("ORDERS"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            if lLab.isLoading && lLab.orders.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.filmAccent)
                    Text(L("Loading orders..."))
                        .font(.system(size: 14))
                        .foregroundColor(Color.filmTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
            } else if lLab.orders.isEmpty && lLab.pickupOrders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(Color.filmTertiary)
                    Text(L("No orders yet"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Text(L("Your LLab orders will appear here"))
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lLab.orders.enumerated()), id: \.element.id) { index, order in
                        orderRow(order)
                        if index < lLab.orders.count - 1 {
                            Divider().background(Color.filmBorder.opacity(0.3))
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )

                if !lLab.pickupOrders.isEmpty {
                    Text(L("PICKUP ORDERS"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(lLab.pickupOrders.enumerated()), id: \.element.id) { index, order in
                            pickupOrderRow(order)
                            if index < lLab.pickupOrders.count - 1 {
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

    private func orderRow(_ order: LLabOrder) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(order.orderNumber)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.filmText)

                HStack(spacing: 6) {
                    if let type = order.orderItems?.first?.filmType {
                        Text(type)
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmTertiary)
                    }
                    if let size = order.orderItems?.first?.filmSize {
                        Text(size)
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmTertiary.opacity(0.7))
                    }
                    if order.totalRolls > 1 {
                        Text("\u{00D7}\(order.totalRolls)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                HStack(spacing: 12) {
                    if order.totalPrice > 0 {
                        Text(formatVND(order.totalPrice))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.filmAccent)
                    }
                    if let date = order.createdAt {
                        Text(formatDate(date))
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmTertiary.opacity(0.7))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                statusBadge(order.status)
                if let scanner = order.scanner {
                    Text(scanner)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.filmTertiary.opacity(0.5))
                }
            }
        }
        .padding(16)
    }

    private func pickupOrderRow(_ order: LLabPickupOrder) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(order.code)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.filmText)
                if let total = order.totalFilm {
                    Text(L("%d film(s)", total))
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .lineLimit(1)
                }
                if let createdOn = order.createdAt {
                    Text(formatDate(createdOn))
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmTertiary.opacity(0.7))
                }
            }

            Spacer()

            statusBadge(order.status)
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

    private func formatDate(_ iso: String) -> String {
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
