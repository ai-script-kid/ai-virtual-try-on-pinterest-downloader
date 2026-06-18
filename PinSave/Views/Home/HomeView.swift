import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var vm = HomeViewModel()

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    urlSection
                    if let pin = vm.downloadedPin {
                        resultSection(pin: pin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        emptyState
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .appNavBar(title: "Download") { showSettings = true }
        }
        .tint(.terracotta)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(subscriptionService)
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView().environmentObject(subscriptionService)
        }
        .alert("Oops", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.downloadedPin)
        .onChange(of: vm.showSavedToPhotos) { _, show in
            if show {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    vm.showSavedToPhotos = false
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.terracotta.opacity(0.07))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Color.terracotta.opacity(0.05))
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.terracotta.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("Paste a Pinterest link")
                    .font(.app(.title3, weight: .bold))
                    .foregroundStyle(.textPrimary)
                Text("Any image or video from Pinterest\ndownloads in seconds.")
                    .font(.app(.subheadline))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            HStack(spacing: 24) {
                tipItem(icon: "link", text: "Copy link")
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.warmBorder)
                tipItem(icon: "doc.on.clipboard", text: "Paste above")
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.warmBorder)
                tipItem(icon: "arrow.down.circle", text: "Download")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }

    private func tipItem(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.terracotta.opacity(0.7))
            Text(text)
                .font(.app(.caption2, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - URL Input

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Paste a Pinterest link")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.textPrimary)
            } icon: {
                Image(systemName: "link")
                    .foregroundStyle(.terracotta)
            }

            HStack(spacing: 10) {
                TextField("https://pinterest.com/pin/…", text: $vm.urlText)
                    .font(.app(.body))
                    .foregroundStyle(Color.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await vm.download(uid: appState.uid ?? "", isPremium: subscriptionService.isPremium) }
                    }

                Button(action: vm.pasteFromClipboard) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 40, height: 40)
                        .background(Color.terracotta.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(14)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.warmBorder, lineWidth: 1)
            )

            Button {
                Task { await vm.download(uid: appState.uid ?? "", isPremium: subscriptionService.isPremium) }
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Downloading…")
                            .font(.app(.body, weight: .bold))
                    } else {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 15, weight: .bold))
                        Text("Download")
                            .font(.app(.body, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(vm.urlText.isEmpty ? Color.warmBorder : Color.terracotta)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .animation(.easeInOut(duration: 0.15), value: vm.urlText.isEmpty)
            }
            .disabled(vm.urlText.isEmpty || vm.isLoading)

            if !subscriptionService.isPremium {
                HStack(spacing: 5) {
                    Image(systemName: "gift")
                        .font(.system(size: 11))
                    Text("1 free download · Subscribe for unlimited")
                        .font(.app(.caption))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 2)
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - Result Card

    private func resultSection(pin: PinDownload) -> some View {
        VStack(spacing: 0) {
            // Image — natural size, no cropping
            if let url = URL(string: pin.thumbnailUrl.isEmpty ? (pin.imageUrl ?? "") : pin.thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .topLeading) {
                                if pin.isVideo {
                                    Label("Video", systemImage: "play.fill")
                                        .font(.app(.caption2, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.terracotta)
                                        .clipShape(Capsule())
                                        .padding(12)
                                }
                            }
                    case .failure:
                        Color.warmBorder
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.textSecondary)
                            )
                    default:
                        Color.warmBorder
                            .aspectRatio(4/3, contentMode: .fit)
                            .overlay(ProgressView().tint(Color.textSecondary))
                    }
                }
            }

            // Action bar
            VStack(spacing: 12) {
                if let title = pin.title, !title.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sageGreen)
                        Text(title)
                            .font(.app(.footnote))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sageGreen)
                        Text("Downloaded successfully")
                            .font(.app(.subheadline, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    // Download / Save to Photos button
                    if !pin.isVideo, pin.imageUrl != nil {
                        Button {
                            Task { await vm.saveToPhotos(pin: pin) }
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isPhotoSaving {
                                    ProgressView()
                                        .tint(Color.textPrimary)
                                        .scaleEffect(0.8)
                                    Text("Saving…")
                                        .font(.app(.subheadline, weight: .medium))
                                        .foregroundStyle(.textPrimary)
                                } else if vm.showSavedToPhotos {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.sageGreen)
                                    Text("Saved!")
                                        .font(.app(.subheadline, weight: .semibold))
                                        .foregroundStyle(Color.sageGreen)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Save")
                                        .font(.app(.subheadline, weight: .medium))
                                        .foregroundStyle(.textPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(vm.showSavedToPhotos
                                ? Color.sageGreen.opacity(0.1)
                                : Color.appBackground)
                            .foregroundStyle(.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(vm.showSavedToPhotos ? Color.sageGreen.opacity(0.4) : Color.warmBorder, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.2), value: vm.isPhotoSaving)
                            .animation(.easeInOut(duration: 0.2), value: vm.showSavedToPhotos)
                        }
                        .disabled(vm.isPhotoSaving || vm.showSavedToPhotos)
                    }

                    // Try On button
                    if !pin.isVideo {
                        Button {
                            appState.pendingTryOnPin = pin
                            appState.selectedTab = 2
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.sparkles")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Try On")
                                    .font(.app(.subheadline, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.terracotta)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }

                    // New / reset button
                    Button { vm.downloadedPin = nil; vm.urlText = "" } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.warmBorder.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
        .cardStyle()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Toast

struct ToastView: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.app(.subheadline, weight: .medium))
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}
