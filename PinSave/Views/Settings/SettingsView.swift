import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    planCard
                    accountSection
                    legalSection
                    appSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.app(.subheadline, weight: .bold))
                        .foregroundStyle(.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.warmBorder)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .tint(.terracotta)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(subscriptionService)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(subscriptionService.isPremium
                              ? Color.terracotta.opacity(0.12)
                              : Color.warmBorder.opacity(0.5))
                        .frame(width: 48, height: 48)
                    Image(systemName: subscriptionService.isPremium ? "crown.fill" : "person.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(subscriptionService.isPremium ? Color.terracotta : Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(subscriptionService.isPremium ? "Premium" : "Free Plan")
                        .font(.app(.subheadline, weight: .bold))
                        .foregroundStyle(.textPrimary)
                    if subscriptionService.isPremium {
                        Text("\(subscriptionService.tryOnCredits) AI try-on credits remaining")
                            .font(.app(.caption))
                            .foregroundStyle(subscriptionService.tryOnCredits == 0 ? Color.terracotta : Color.textSecondary)
                    } else {
                        Text("1 free download · no AI try-on")
                            .font(.app(.caption))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                if subscriptionService.isPremium {
                    Text("Active")
                        .font(.app(.caption2, weight: .bold))
                        .foregroundStyle(Color.sageGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.sageGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if !subscriptionService.isPremium {
                Button { showPaywall = true } label: {
                    Text("Upgrade to Premium")
                        .font(.app(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.terracotta)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Account")

            VStack(spacing: 0) {
                Button {
                    isRestoring = true
                    Task {
                        do {
                            try await subscriptionService.restore()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isRestoring = false
                    }
                } label: {
                    settingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        label: "Restore Purchases",
                        trailing: isRestoring ? AnyView(ProgressView().tint(Color.terracotta).scaleEffect(0.8)) : AnyView(chevron)
                    )
                }

                Divider().background(Color.warmBorder).padding(.leading, 52)
            }
            .cardStyle()
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Legal")

            VStack(spacing: 0) {
                Link(destination: URL(string: "https://arsprogrammatica.com/pin-privacy")!) {
                    settingsRow(
                        icon: "lock.shield",
                        label: "Privacy Policy",
                        trailing: AnyView(chevron)
                    )
                }

                Divider().background(Color.warmBorder).padding(.leading, 52)

                Link(destination: URL(string: "https://arsprogrammatica.com/pin-terms")!) {
                    settingsRow(
                        icon: "doc.text",
                        label: "Terms of Use",
                        trailing: AnyView(chevron)
                    )
                }
            }
            .cardStyle()
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(spacing: 0) {
            sectionLabel("App")

            VStack(spacing: 0) {
                settingsRow(
                    icon: "info.circle",
                    label: "Version",
                    trailing: AnyView(
                        Text(appVersion)
                            .font(.app(.caption))
                            .foregroundStyle(Color.textSecondary)
                    )
                )
                .allowsHitTesting(false)
            }
            .cardStyle()
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.app(.caption2, weight: .bold))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.bottom, 8)
    }

    private func settingsRow(icon: String, label: String, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.terracotta)
                .frame(width: 32, height: 32)
                .background(Color.terracotta.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(label)
                .font(.app(.subheadline))
                .foregroundStyle(.textPrimary)

            Spacer()

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.warmBorder)
    }
}
