import SwiftUI
import PhotosUI

struct TryOnView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var vm = TryOnViewModel()
    @StateObject private var downloadsVm = DownloadsViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPinPicker = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imagePickers
                    if let url = vm.resultImageUrl {
                        resultSection(url: url)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    tryOnButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.resultImageUrl)
            .background(Color.appBackground)
            .appNavBar(title: "Virtual Try On") { showSettings = true }
        }
        .tint(.terracotta)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(subscriptionService)
        }
        .sheet(isPresented: $showPinPicker) {
            PinPickerSheet(downloads: downloadsVm.downloads, selected: $vm.selectedPin)
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
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.userImage = image
                }
            }
        }
        .onAppear {
            if let uid = appState.uid { downloadsVm.startListening(uid: uid) }
            if let pin = appState.pendingTryOnPin {
                vm.selectedPin = pin
                appState.pendingTryOnPin = nil
            }
        }
        .onChange(of: appState.pendingTryOnPin) { _, pin in
            if let pin {
                vm.selectedPin = pin
                appState.pendingTryOnPin = nil
            }
        }
    }

    // MARK: - Banner

    private var descriptionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 24))
                .foregroundStyle(Color.terracotta)
                .frame(width: 48, height: 48)
                .background(Color.terracotta.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Virtual Try On")
                    .font(.app(.subheadline, weight: .bold))
                    .foregroundStyle(.textPrimary)
                Text("Pick a pin + your photo, then let AI do the magic")
                    .font(.app(.caption))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Image Pickers

    private var imagePickers: some View {
        HStack(spacing: 12) {
            pinPickerPanel
            userPhotoPanel
        }
    }

    private var pinPickerPanel: some View {
        Button { showPinPicker = true } label: {
            if let pin = vm.selectedPin,
               let url = URL(string: pin.imageUrl ?? pin.thumbnailUrl),
               !pin.thumbnailUrl.isEmpty || pin.imageUrl != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.sageGreen)
                                    .background(Circle().fill(.white))
                                    .padding(8)
                            }
                    default:
                        ZStack {
                            Color.terracotta.opacity(0.05)
                            ProgressView().tint(Color.terracotta)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(Color.terracotta.opacity(0.35))
                        )
                    }
                }
                .id(pin.id)
            } else {
                emptyPanel(icon: "photo.badge.plus", label: "Pinterest\nImage")
            }
        }
    }

    private var userPhotoPanel: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            pickerPanelContent(
                uiImage: vm.userImage,
                emptyIcon: "person.crop.circle.badge.plus",
                emptyLabel: "Your\nPhoto"
            )
        }
    }

    @ViewBuilder
    private func pickerPanelContent(
        image: URL? = nil,
        uiImage: UIImage? = nil,
        asyncLoading: Bool = false,
        emptyIcon: String,
        emptyLabel: String
    ) -> some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sageGreen)
                            .background(Circle().fill(.white))
                            .padding(8)
                    }
            } else if let image, asyncLoading {
                AsyncImage(url: image) { img in
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sageGreen)
                                .background(Circle().fill(.white))
                                .padding(8)
                        }
                } placeholder: {
                    emptyPanel(icon: emptyIcon, label: emptyLabel)
                }
            } else {
                emptyPanel(icon: emptyIcon, label: emptyLabel)
            }
        }
    }

    private func emptyPanel(icon: String, label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.terracotta)
            Text(label)
                .font(.app(.caption, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .background(Color.terracotta.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(Color.terracotta.opacity(0.35))
        )
    }

    // MARK: - Try On Button

    private var tryOnButton: some View {
        let ready = vm.selectedPin != nil && vm.userImage != nil && !vm.isLoading

        return VStack(spacing: 10) {
        if subscriptionService.isPremium {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(subscriptionService.tryOnCredits) credits remaining")
                    .font(.app(.caption, weight: .medium))
            }
            .foregroundStyle(subscriptionService.tryOnCredits == 0 ? Color.terracotta : Color.textSecondary)
        }
        Button {
            Task { await vm.runTryOn() }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Processing…")
                        .font(.app(.body, weight: .bold))
                } else {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Try On")
                        .font(.app(.body, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(ready ? Color.terracotta : Color.warmBorder)
            .foregroundStyle(ready ? Color.white : Color.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: ready)
        }
        .disabled(!ready)
        } // VStack
    }

    // MARK: - Result

    private func resultSection(url: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.warmBorder
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: 10) {
                                ProgressView().tint(Color.terracotta)
                                Text("Rendering result…")
                                    .font(.app(.caption))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)

                Divider()
                    .background(Color.warmBorder)

                HStack(spacing: 10) {
                    ShareLink(item: imageUrl) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.app(.subheadline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.terracotta)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }

                    Button { vm.reset() } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.app(.subheadline, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.appBackground)
                            .foregroundStyle(.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(Color.warmBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .cardStyle()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Pin Picker Sheet

struct PinPickerSheet: View {
    let downloads: [PinDownload]
    @Binding var selected: PinDownload?
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if downloads.filter({ !$0.isVideo }).isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.terracotta.opacity(0.4))
                        Text("No images yet")
                            .font(.app(.title3, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Text("Download a Pinterest image first")
                            .font(.app(.subheadline))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(downloads.filter { !$0.isVideo }) { pin in
                                AsyncImage(url: URL(string: pin.thumbnailUrl)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.warmBorder
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            selected?.id == pin.id ? Color.terracotta : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .overlay(alignment: .topTrailing) {
                                    if selected?.id == pin.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.terracotta)
                                            .background(Circle().fill(.white))
                                            .padding(5)
                                    }
                                }
                                .onTapGesture {
                                    selected = pin
                                    dismiss()
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Select Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.app(.body, weight: .medium))
                }
            }
        }
        .tint(.terracotta)
    }
}
