import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let features: [(String, String, String)] = [
        ("arrow.down.circle.fill",     "Unlimited Downloads", "Save any Pinterest image or video"),
        ("wand.and.sparkles",          "AI Virtual Try On",   "Try on looks with Nano Banana AI"),
        ("bolt.fill",                  "Priority Processing",  "Faster results, always")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featuresSection
                    packagesSection
                    subscribeButton
                    restoreButton
                    legalText
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.warmBorder)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .tint(.terracotta)
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await subscriptionService.refresh() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.terracotta.opacity(0.1))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Color.terracotta.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "pin.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.terracotta)
            }

            Text("PinSave Premium")
                .font(.app(.title2, weight: .heavy))
                .foregroundStyle(.textPrimary)

            Text("Download without limits and try on anything you love")
                .font(.app(.body))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 2) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                let (icon, title, subtitle) = feature
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 36, height: 36)
                        .background(Color.terracotta.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.app(.subheadline, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Text(subtitle)
                            .font(.app(.caption))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.sageGreen)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if feature.0 != features.last?.0 {
                    Divider()
                        .background(Color.warmBorder)
                        .padding(.horizontal, 16)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Packages

    @ViewBuilder
    private var packagesSection: some View {
        if let packages = subscriptionService.offerings?.current?.availablePackages, !packages.isEmpty {
            VStack(spacing: 10) {
                ForEach(packages, id: \.identifier) { package in
                    PackageRow(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier
                    )
                    .onTapGesture { selectedPackage = package }
                }
            }
            .onAppear {
                selectedPackage = packages.first(where: { $0.storeProduct.productIdentifier == "pinyearly" }) ?? packages.first
            }
        } else {
            noProductsView
        }
    }

    private var noProductsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 30))
                .foregroundStyle(Color.terracotta.opacity(0.5))
            Text("Subscriptions coming soon")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(.textPrimary)
            Text("We're finalising pricing. Check back shortly.")
                .font(.app(.caption))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            guard let package = selectedPackage else { return }
            isLoading = true
            Task {
                do {
                    try await subscriptionService.purchase(package: package)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                }
                Text(isLoading ? "Processing…" : "Subscribe Now")
                    .font(.app(.body, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(selectedPackage == nil ? Color.warmBorder : Color.terracotta)
            .foregroundStyle(selectedPackage == nil ? Color.textSecondary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: selectedPackage == nil)
        }
        .disabled(selectedPackage == nil || isLoading)
    }

    // MARK: - Restore & Legal

    private var restoreButton: some View {
        Button {
            Task {
                do {
                    try await subscriptionService.restore()
                    if subscriptionService.isPremium { dismiss() }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.app(.subheadline, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var legalText: some View {
        VStack(spacing: 6) {
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings > Apple ID > Subscriptions.")
                .font(.app(.caption2))
                .foregroundStyle(Color.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://arsprogrammatica.com/pin-privacy")!)
                Link("Terms of Use", destination: URL(string: "https://arsprogrammatica.com/pin-terms")!)
            }
            .font(.app(.caption2, weight: .medium))
            .tint(Color.textSecondary)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: Package
    let isSelected: Bool

    private var productId: String { package.storeProduct.productIdentifier }
    private var isYearly: Bool { productId == "pinyearly" }

    private var creditSubtitle: String {
        switch productId {
        case "pinweekly": return "Unlimited Downloads • 20 Try On Credits"
        case "pinyearly": return "Unlimited Downloads • 300 Try On Credits"
        default:          return "Unlimited Downloads"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.terracotta : Color.warmBorder, lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color.terracotta)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.app(.subheadline, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    if isYearly {
                        Text("Best Value")
                            .font(.app(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.terracotta)
                            .clipShape(Capsule())
                    }
                }
                Text(creditSubtitle)
                    .font(.app(.caption))
                    .foregroundStyle(Color.textSecondary)
                if package.storeProduct.introductoryDiscount != nil {
                    Text("Free trial included")
                        .font(.app(.caption))
                        .foregroundStyle(Color.sageGreen)
                }
            }

            Spacer()

            Text(package.localizedPriceString)
                .font(.app(.subheadline, weight: .bold))
                .foregroundStyle(isSelected ? Color.terracotta : Color.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? Color.terracotta.opacity(0.06) : Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.terracotta : Color.warmBorder, lineWidth: isSelected ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
