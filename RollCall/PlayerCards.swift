import SwiftUI
import UIKit

struct PlayerCardContent: Equatable, Sendable {
    var playerName: String
    var playerNumber: String?
    var teamName: String?
    var songTitle: String?
    var artistName: String?
    var accentPreset: TeamAccentPreset

    init(
        playerName: String,
        playerNumber: String?,
        teamName: String?,
        songTitle: String?,
        artistName: String?,
        accentPreset: TeamAccentPreset
    ) {
        self.playerName = playerName
        self.playerNumber = playerNumber
        self.teamName = teamName
        self.songTitle = songTitle
        self.artistName = artistName
        self.accentPreset = accentPreset
    }

    init(player: Player, team: Team) {
        playerName = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        playerNumber = player.uniformNumber.nilIfBlank
        teamName = team.name.nilIfBlank
        accentPreset = team.accentPreset

        let source = team.songClip(for: player)?.originalSource
            ?? team.cue(for: player).map { SongSource(cueSource: $0.source) }
        switch source {
        case .appleMusic(let source):
            songTitle = source.title.nilIfBlank
            artistName = source.artistName.nilIfBlank
        case .localAudio(let source):
            let parts = source.displayName.rollCallSongParts
            songTitle = parts.title
            artistName = parts.artist
        case .builtInClip(let source):
            songTitle = source.displayName.nilIfBlank
            artistName = nil
        case nil:
            songTitle = nil
            artistName = nil
        }
    }
}

struct PlayerCardRenderer {
    static let outputSize = CGSize(width: 1_200, height: 1_500)

    func render(
        content: PlayerCardContent,
        photo: UIImage?,
        crop: NormalizedPhotoCrop?,
        brandIcon: UIImage? = nil
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: Self.outputSize, format: format).image { context in
            let canvas = CGRect(origin: .zero, size: Self.outputSize)
            drawBroadcast(content: content, photo: photo, crop: crop, brandIcon: brandIcon, canvas: canvas, context: context.cgContext)
        }
    }

    private func drawBroadcast(content: PlayerCardContent, photo: UIImage?, crop: NormalizedPhotoCrop?, brandIcon: UIImage?, canvas: CGRect, context: CGContext) {
        let accent = content.accentPreset.theme.uiColor(.fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        UIColor(red: 0.035, green: 0.043, blue: 0.06, alpha: 1).setFill()
        context.fill(canvas)
        accent.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 32))
        let photoRect = CGRect(origin: CGPoint(x: 54, y: 82), size: PlayerPhotoFramingGeometry.playerCardPhotoViewportSize)
        context.saveGState()
        UIBezierPath(roundedRect: photoRect, cornerRadius: 34).addClip()
        drawPhoto(photo, crop: crop, in: photoRect, accent: accent, context: context)
        context.restoreGState()
        drawGradient(from: .clear, to: UIColor.black.withAlphaComponent(0.94), in: CGRect(x: 54, y: 590, width: 1_092, height: 392), context: context)

        if let teamName = content.teamName {
            drawText(teamName.uppercased(), in: CGRect(x: 92, y: 112, width: 700, height: 42), font: .systemFont(ofSize: 27, weight: .bold), color: .white, alignment: .left, tracking: 2)
        }
        if let number = content.playerNumber {
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: 936, y: 110, width: 160, height: 90), cornerRadius: 20).fill()
            drawText(number, in: CGRect(x: 948, y: 118, width: 136, height: 74), font: fittedFont(text: number, maxSize: 58, weight: .black, width: 136), color: readableForeground(over: accent), alignment: .center)
        }
        drawText(content.playerName, in: CGRect(x: 90, y: 765, width: 980, height: 164), font: fittedFont(text: content.playerName, maxSize: 86, weight: .black, width: 980), color: .white, alignment: .left)

        let songPanel = CGRect(x: 54, y: 1_020, width: 1_092, height: content.songTitle == nil ? 208 : 310)
        UIColor(red: 0.095, green: 0.105, blue: 0.13, alpha: 1).setFill()
        UIBezierPath(roundedRect: songPanel, cornerRadius: 34).fill()
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: 54, y: 1_020, width: 18, height: songPanel.height), byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 34, height: 34)).fill()
        drawText(content.songTitle == nil ? "READY FOR GAME DAY" : "WALK-UP MUSIC", in: CGRect(x: 100, y: 1_064, width: 900, height: 38), font: .systemFont(ofSize: 25, weight: .bold), color: accent, alignment: .left, tracking: 2.5)
        if let song = content.songTitle {
            drawText(song, in: CGRect(x: 98, y: 1_116, width: 948, height: 92), font: fittedFont(text: song, maxSize: 52, weight: .bold, width: 948), color: .white, alignment: .left)
            if let artist = content.artistName {
                drawText(artist, in: CGRect(x: 100, y: 1_218, width: 900, height: 48), font: .systemFont(ofSize: 31, weight: .medium), color: .white.withAlphaComponent(0.7), alignment: .left)
            }
        }
        drawAttribution(in: CGRect(x: 54, y: 1_382, width: 1_092, height: 66), color: .white.withAlphaComponent(0.7), icon: brandIcon)
    }


    private func drawPhoto(_ image: UIImage?, crop: NormalizedPhotoCrop?, in rect: CGRect, accent: UIColor, context: CGContext) {
        guard let image,
              let prepared = image.cropped(to: crop ?? .full, outputSize: rect.size) else {
            accent.setFill()
            context.fill(rect)
            let symbol = UIImage(systemName: "person.crop.rectangle.fill")?.withTintColor(readableForeground(over: accent).withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
            symbol?.draw(in: rect.insetBy(dx: rect.width * 0.32, dy: rect.height * 0.32))
            return
        }
        prepared.draw(in: rect)
    }

    private func drawGradient(from start: UIColor, to end: UIColor, in rect: CGRect, context: CGContext) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [start.cgColor, end.cgColor] as CFArray, locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    }

    private func drawAttribution(in rect: CGRect, color: UIColor, icon: UIImage?) {
        let iconRect = CGRect(x: rect.minX, y: rect.midY - 23, width: 46, height: 46)
        if let icon = icon ?? UIImage(named: "AppIcon") ?? UIImage(named: "RollCallDocumentIcon-320x320") {
            UIGraphicsGetCurrentContext()?.saveGState()
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 10)
            path.addClip()
            icon.draw(in: iconRect)
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
        drawText("Made with Roll Call", in: CGRect(x: rect.minX + 62, y: rect.minY, width: rect.width - 62, height: rect.height), font: .systemFont(ofSize: 25, weight: .semibold), color: color, alignment: .left)
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment, tracking: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: tracking
        ]
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private func fittedFont(text: String, maxSize: CGFloat, weight: UIFont.Weight, width: CGFloat) -> UIFont {
        var size = maxSize
        while size > 24 {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            if NSString(string: text).size(withAttributes: [.font: font]).width <= width { return font }
            size -= 2
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    private func readableForeground(over color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? .black : .white
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var rollCallSongParts: (title: String?, artist: String?) {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in [" — ", " – ", " - "] {
            let pieces = value.components(separatedBy: separator)
            if pieces.count >= 2 {
                return (pieces.dropFirst().joined(separator: separator).nilIfBlank, pieces.first?.nilIfBlank)
            }
        }
        return (value.nilIfBlank, nil)
    }
}

struct PlayerCardImageView: View {
    let image: UIImage
    let playerName: String

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
            .accessibilityLabel("Player Card preview for \(playerName)")
    }
}

struct PlayerCardPreviewSheet: View {
    private struct RenderOutput: @unchecked Sendable {
        let card: UIImage
        let framingImage: UIImage?
        let usesWorkingMaster: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @Binding var player: Player
    let team: Team
    let onGenerated: () -> Void
    let onGenerationFailed: (String) -> Void
    let onSharePresented: () -> Void
    let onCardFramingAdjusted: () -> Void

    @State private var renderedImage: UIImage?
    @State private var shareImage: UIImage?
    @State private var framingImage: UIImage?
    @State private var framingUsesWorkingMaster = false
    @State private var framingPresented = false
    @State private var renderError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let renderedImage {
                        PlayerCardImageView(image: renderedImage, playerName: player.displayName)
                            .padding(.horizontal, 20)
                    } else if let renderError {
                        ContentUnavailableView(
                            "Card Unavailable",
                            systemImage: "photo.badge.exclamationmark",
                            description: Text(renderError)
                        )
                        .frame(minHeight: 420)
                    } else {
                        ProgressView("Creating Player Card…")
                            .frame(minHeight: 420)
                    }

                    if framingImage != nil {
                        Button {
                            framingPresented = true
                        } label: {
                            Label("Adjust Player Card Photo", systemImage: "crop")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Changes only the framing used in the shared Player Card.")
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Player Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let renderedImage else { return }
                        shareImage = renderedImage
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(renderedImage == nil)
                }
            }
            .task(id: renderIdentity) {
                await render()
            }
            .sheet(isPresented: Binding(
                get: { shareImage != nil },
                set: { if !$0 { shareImage = nil } }
            )) {
                if let shareImage {
                    PlayerCardActivityShareSheet(items: [shareImage])
                        .onAppear(perform: onSharePresented)
                }
            }
            .fullScreenCover(isPresented: $framingPresented) {
                if let framingImage {
                    PhotoFramingEditorSheet(
                        image: framingImage,
                        initialCrop: effectiveCardCrop(for: framingImage),
                        aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                        title: "Adjust Player Card Photo",
                        onCancel: { framingPresented = false },
                        onApply: { crop in
                            if player.photoSourceRelativePath != nil, !framingUsesWorkingMaster {
                                player.photoSourceRelativePath = nil
                                player.profilePhotoCrop = nil
                            }
                            player.playerCardPhotoCrop = crop
                            framingPresented = false
                            onCardFramingAdjusted()
                        }
                    )
                }
            }
        }
    }

    private var renderIdentity: String {
        [
            player.displayName,
            player.uniformNumber,
            player.photoRelativePath ?? "",
            player.photoSourceRelativePath ?? "",
            String(describing: player.playerCardPhotoCrop)
        ].joined(separator: "|")
    }

    private func render() async {
        renderedImage = nil
        renderError = nil
        let content = PlayerCardContent(player: player, team: team)
        let sourceURL = assetURL(relativePath: player.photoSourceRelativePath)
        let legacyURL = assetURL(relativePath: player.photoRelativePath)
        let storedCrop = player.playerCardPhotoCrop

        let output = await Task.detached(priority: .userInitiated) {
            let sourceImage = Self.loadPhoto(at: sourceURL)
            let image = sourceImage ?? Self.loadPhoto(at: legacyURL)
            let crop = image.map { image in
                let usableStoredCrop = sourceURL == nil || sourceImage != nil ? storedCrop : nil
                return usableStoredCrop ?? PlayerPhotoFramingGeometry.centeredCrop(
                    aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                    imageSize: image.size
                )
            }
            return RenderOutput(
                card: PlayerCardRenderer().render(content: content, photo: image, crop: crop),
                framingImage: image,
                usesWorkingMaster: sourceImage != nil
            )
        }.value

        guard !Task.isCancelled else { return }
        framingImage = output.framingImage
        framingUsesWorkingMaster = output.usesWorkingMaster
        guard output.card.cgImage != nil else {
            renderedImage = nil
            renderError = "Roll Call couldn't finish this card. Please try again."
            onGenerationFailed("unknown")
            return
        }
        renderedImage = output.card
        renderError = nil
        onGenerated()
    }

    private func effectiveCardCrop(for image: UIImage) -> NormalizedPhotoCrop {
        if (player.photoSourceRelativePath == nil || framingUsesWorkingMaster),
           let crop = player.playerCardPhotoCrop {
            return crop
        }
        return PlayerPhotoFramingGeometry.centeredCrop(
            aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
            imageSize: image.size
        )
    }

    private func assetURL(relativePath: String?) -> URL? {
        guard let relativePath,
              let url = try? AppPaths.assetURL(relativePath: relativePath) else { return nil }
        return url
    }

    nonisolated private static func loadPhoto(at url: URL?) -> UIImage? {
        guard let url,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct PlayerCardActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
