import DiscordKit
import SwiftUI

#if canImport(UIKit)
import PhotosUI
#endif

struct IOSComposerBar: View {
    @Environment(IOSAppModel.self) private var model
    #if canImport(UIKit)
    @State private var selectedPhotos = [PhotosPickerItem]()
    #endif
    @State private var attachmentPreviews = [AttachmentPreview]()

    var body: some View {
        @Bindable var composer = model.composer

        VStack(spacing: 0) {
            Divider()

            if let replyTarget = composer.replyTarget {
                replyBanner(replyTarget)
            }

            if let error = composer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            if !attachmentPreviews.isEmpty {
                attachmentStrip
            }

            HStack(spacing: 8) {
                #if canImport(UIKit)
                PhotosPicker(
                    selection: $selectedPhotos,
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                #else
                Button {
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                #endif

                TextField("Message", text: $composer.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .onSubmit {
                        Task { await sendWithAttachments() }
                    }

                Button {
                    Task { await sendWithAttachments() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(composer.canSend ? Color.accentColor : Color.gray)
                }
                .disabled(!composer.canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
        #if canImport(UIKit)
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await loadPhotos(newPhotos)
            }
        }
        #endif
    }

    private func replyBanner(_ target: MessageReplyTarget) -> some View {
        HStack {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)

            Text("Replying to **\(target.authorDisplayName)**")
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Button {
                model.composer.cancelReply()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.12))
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachmentPreviews) { preview in
                    ZStack(alignment: .topTrailing) {
                        if let image = preview.thumbnail {
                            thumbnailImage(image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.tertiary)
                                }
                        }

                        Button {
                            attachmentPreviews.removeAll { $0.id == preview.id }
                            model.composer.hasAttachments = !attachmentPreviews.isEmpty
                            #if canImport(UIKit)
                            selectedPhotos.removeAll()
                            #endif
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    private func sendWithAttachments() async {
        let attachments = attachmentPreviews.enumerated().map { index, preview in
            MessageAttachmentInput(
                id: index,
                filename: preview.filename,
                data: preview.data,
                contentType: "image/png"
            )
        }
        await model.sendMessage(attachments: attachments)
        attachmentPreviews.removeAll()
        #if canImport(UIKit)
        selectedPhotos.removeAll()
        #endif
    }

    private func thumbnailImage(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }

    #if canImport(UIKit)
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var previews = [AttachmentPreview]()
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let image = PlatformImage(data: data)
                previews.append(AttachmentPreview(
                    id: item.itemIdentifier ?? UUID().uuidString,
                    thumbnail: image,
                    data: data,
                    filename: "image.png"
                ))
            }
        }
        attachmentPreviews = previews
        model.composer.hasAttachments = !previews.isEmpty
    }
    #endif
}

struct AttachmentPreview: Identifiable {
    let id: String
    var thumbnail: PlatformImage?
    let data: Data
    let filename: String
}

extension AttachmentPreview: @unchecked Sendable {}
