import XCTest
import UIKit
@testable import RollCall

final class PlayerCardTests: XCTestCase {
    func testSelectedDesignRendersFourByFiveAtExpectedPixelSize() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .blue)
        let photo = samplePhoto()

        let image = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team),
            photo: photo,
            crop: PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: photo.size)
        )
        XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
        XCTAssertEqual(image.size.width / image.size.height, 4.0 / 5.0, accuracy: 0.0001)
        XCTAssertNotNil(image.pngData())
    }

    func testMissingOptionalContentAndPhotoStillRender() {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Taylor", number: "")
        player.songAssignment = nil
        var team = team(containing: player, accent: .purple)
        team.name = ""

        let image = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team),
            photo: nil,
            crop: nil
        )

        XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
        XCTAssertNotNil(image.jpegData(compressionQuality: 0.8))
    }

    func testLegacyTightCropRendersWithoutMaster() {
        let player = playerWithSong()
        let team = team(containing: player, accent: .red)
        let tight = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
        }
        let crop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: tight.size)

        XCTAssertNotNil(PlayerCardRenderer().render(content: PlayerCardContent(player: player, team: team), photo: tight, crop: crop).pngData())
    }

    func testTeamAccentChangesRenderedGraphic() throws {
        let player = playerWithSong()
        let photo = samplePhoto()
        let crop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: photo.size)
        let blue = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team(containing: player, accent: .blue)),
            photo: photo,
            crop: crop
        )
        let red = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team(containing: player, accent: .red)),
            photo: photo,
            crop: crop
        )

        XCTAssertNotEqual(try XCTUnwrap(blue.pngData()), try XCTUnwrap(red.pngData()))
    }

    func testGeneratedAppleMusicClipKeepsOriginalArtistOnCard() throws {
        var player = playerWithSong()
        var clip = try XCTUnwrap(player.songAssignment?.privateClip)
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "prepared.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: .now
        )
        player.songAssignment = .privateClip(clip)

        let content = PlayerCardContent(player: player, team: team(containing: player, accent: .blue))

        XCTAssertEqual(content.songTitle, "Thunderstruck")
        XCTAssertEqual(content.artistName, "AC/DC")
    }

    private func playerWithSong() -> Player {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Alex Ramirez", number: "12")
        player.songAssignment = .privateClip(
            SongClip(cue: Cue(
                id: UUID(),
                label: "Thunderstruck",
                source: .appleMusic(AppleMusicSource(songID: "fixture", title: "Thunderstruck", artistName: "AC/DC", duration: 292, previewURL: nil)),
                startTime: 0,
                duration: 12,
                fadeOutDuration: 0.35,
                pauseAfterAnnouncer: 0.2
            ))
        )
        return player
    }

    private func team(containing player: Player, accent: TeamAccentPreset) -> Team {
        var team = RollCallTestFixtures.team(players: [player])
        team.name = "Northside Falcons"
        team.accentPreset = accent
        return team
    }

    private func samplePhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1_000, height: 1_500)).image { context in
            UIColor(red: 0.12, green: 0.22, blue: 0.38, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 1_500))
            UIColor.systemOrange.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 300, y: 180, width: 400, height: 400))
            UIColor.white.setFill()
            context.fill(CGRect(x: 230, y: 570, width: 540, height: 780))
        }
    }

}
