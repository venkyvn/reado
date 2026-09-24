import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    var collectionId: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showDestPick = false
    @State private var showCreate = false
    @State private var createName = ""
    @State private var didAutoPresent = false

    private var dest: CollectionRecord {
        let id = store.captureTargetId ?? collectionId ?? store.inbox.id
        return store.collections.first(where: { $0.id == id }) ?? store.inbox
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Huỷ") { pop() }.frame(minHeight: 44)
                Spacer()
                Text("Chụp trang").font(.headline)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            DestChip(name: dest.name, isInbox: dest.isDefault, onPick: { showDestPick = true }, onCreate: { showCreate = true })
            if let image = store.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(store.previewRotation.degrees))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxHeight: 360)
            } else {
                VStack(spacing: 8) {
                    Text("Chụp hoặc chọn ảnh trang").font(.headline)
                    Text("OCR + dịch + vocab · mock").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            HStack(spacing: 10) {
                Button("Camera") { showCamera = true }.frame(minHeight: 44)
                Button(store.previewImage == nil ? "Thư viện" : "Đổi ảnh") { showLibrary = true }
                    .frame(minHeight: 44)
                if store.previewImage != nil {
                    Button("Xoay") { store.rotatePreview() }.frame(minHeight: 44)
                }
            }
            PrimaryButton(
                title: store.analyzing ? "Đang phân tích…" : (store.previewImage == nil ? "Dùng trang mẫu" : "Phân tích ảnh này"),
                enabled: !store.analyzing
            ) {
                Task { await analyze() }
            }
            Spacer()
        }
        .padding(18)
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            if store.captureTargetId == nil {
                store.beginCapture(collectionId: collectionId)
            }
            if !didAutoPresent, store.previewImage == nil {
                didAutoPresent = true
                showCamera = true
            }
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    store.previewImage = image
                    store.previewRotation = .zero
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(
                destName: dest.name,
                isInbox: dest.isDefault,
                onPickDest: { showDestPick = true },
                onCreate: { showCreate = true },
                onLibrary: {
                    showCamera = false
                    showLibrary = true
                },
                onImage: { image in
                    store.previewImage = image
                    store.previewRotation = .zero
                    showCamera = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                },
                onCancel: {
                    showCamera = false
                    if store.previewImage == nil { pop() }
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showDestPick) {
            DestPickSheet(selectedId: dest.id, collections: store.collections) { id in
                store.setCaptureTarget(id)
                showDestPick = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form { TextField("Tên sách / mảng việc", text: $createName) }
                    .navigationTitle("Tạo collection")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") { showCreate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Tạo") { createCollection() }
                                .disabled(createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .overlay {
            if store.analyzing {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("OCR + dịch + vocab · mock").font(.subheadline)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    private func createCollection() {
        let trimmed = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try store.addCollection(name: trimmed)
            store.setCaptureTarget(created.id)
            createName = ""
            showCreate = false
        } catch {
            store.notify(error.localizedDescription)
        }
    }

    private func analyze() async {
        do {
            try await store.analyzePreview()
            path.append(.vocab)
        } catch {
            store.notify(error.localizedDescription)
        }
    }
}

struct DestPickSheet: View {
    var selectedId: String
    var collections: [CollectionRecord]
    var onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List(collections) { collection in
                Button { onSelect(collection.id) } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(collection.name)
                            if collection.isDefault {
                                Text("Mặc định · không chọn thì vào đây")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selectedId == collection.id ? "circle.inset.filled" : "circle")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .navigationTitle("Lưu trang vào")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let store = try! AppStore(database: AppDatabase(inMemory: true))
    CaptureView(path: .constant([]), collectionId: store.inbox.id)
        .environment(store)
}
