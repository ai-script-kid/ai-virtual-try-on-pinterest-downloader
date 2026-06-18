import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var vm = DownloadsViewModel()
    @State private var selectedPin: PinDownload?
    @State private var pinToDelete: PinDownload?
    @State private var showDeleteConfirm = false
    @State private var showSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    loadingState
                } else if vm.downloads.isEmpty {
                    emptyState
                } else {
                    downloadGrid
                }
            }
            .background(Color.appBackground)
            .appNavBar(title: "Downloads") { showSettings = true }
        }
        .tint(.terracotta)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(subscriptionService)
        }
        .sheet(item: $selectedPin) { FullScreenMediaView(pin: $0) }
        .confirmationDialog("Remove this download?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let pin = pinToDelete {
                    Task { await vm.delete(pin: pin, uid: appState.uid ?? "") }
                }
            }
        }
        .onAppear {
            if let uid = appState.uid { vm.startListening(uid: uid) }
        }
        .onDisappear { vm.stopListening() }
        .onChange(of: appState.uid) { _, uid in
            if let uid { vm.startListening(uid: uid) }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.terracotta)
            Text("Loading…")
                .font(.app(.subheadline))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.terracotta.opacity(0.08))
                    .frame(width: 96, height: 96)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.terracotta.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text("Nothing here yet")
                    .font(.app(.title3, weight: .bold))
                    .foregroundStyle(.textPrimary)
                Text("Paste a Pinterest link on the Home tab\nto save your first image or video.")
                    .font(.app(.subheadline))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var downloadGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.downloads) { pin in
                    DownloadCell(pin: pin)
                        .onTapGesture { selectedPin = pin }
                        .contextMenu {
                            Button(role: .destructive) {
                                pinToDelete = pin
                                showDeleteConfirm = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Cell

struct DownloadCell: View {
    let pin: PinDownload

    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: pin.thumbnailUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.warmBorder
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(Color.textSecondary)
                        )
                default:
                    Color.warmBorder
                        .overlay(ProgressView().tint(Color.textSecondary))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.72, contentMode: .fit)
            .clipped()

            if pin.isVideo {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 60)

                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Video")
                        .font(.app(.caption2, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.bottom, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.warmBorder, lineWidth: 1)
        )
        .shadow(color: Color.textPrimary.opacity(0.06), radius: 6, y: 2)
    }
}
