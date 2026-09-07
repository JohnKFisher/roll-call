import XCTest
import UIKit
@testable import RollCall

final class PlayerPhotoTests: XCTestCase {
    private struct LegacyPlayerPhotoView: Decodable {
        var id: UUID
        var displayName: String
        var photoRelativePath: String?
    }

    func testLegacyPlayerDecodesWithoutNewPhotoFields() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "displayName": "Legacy Player",
          "uniformNumber": "7",
          "pronunciationOverride": "",
          "photoRelativePath": "legacy.jpg",
          "isPresent": true
        }
        """

        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertEqual(player.photoRelativePath, "legacy.jpg")
        XCTAssertNil(player.photoSourceRelativePath)
        XCTAssertNil(player.profilePhotoCrop)
        XCTAssertNil(player.playerCardPhotoCrop)
    }

    func testNewPhotoFieldsRoundTrip() throws {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Player", number: "1", photoRelativePath: "profile.jpg")
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.8)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)

        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(player))

        XCTAssertEqual(decoded, player)
    }

    func testLegacyDecoderKeepsProfilePhotoAndIgnoresAdditivePhotoFields() throws {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Player", number: "1", photoRelativePath: "profile.jpg")
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)

        let legacyView = try JSONDecoder().decode(LegacyPlayerPhotoView.self, from: JSONEncoder().encode(player))

        XCTAssertEqual(legacyView.id, player.id)
        XCTAssertEqual(legacyView.displayName, player.displayName)
        XCTAssertEqual(legacyView.photoRelativePath, "profile.jpg")
    }

    func testFaceAndPersonProduceIndependentAspectCorrectFramings() {
        let imageSize = CGSize(width: 1_600, height: 900)
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [CGRect(x: 0.46, y: 0.16, width: 0.12, height: 0.18)],
            people: [CGRect(x: 0.31, y: 0.1, width: 0.42, height: 0.83)],
            imageSize: imageSize
        )

        XCTAssertEqual(analysis.result, .faceAndPerson)
        assertPhysicalAspect(analysis.profileCrop, imageSize: imageSize, expected: 1)
        assertPhysicalAspect(analysis.cardCrop, imageSize: imageSize, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        XCTAssertLessThan(analysis.profileCrop.height, analysis.cardCrop.height)
    }

    func testMultiplePeopleFavorLargeCentralSubject() {
        let imageSize = CGSize(width: 1_000, height: 1_500)
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [
                CGRect(x: 0.05, y: 0.2, width: 0.08, height: 0.08),
                CGRect(x: 0.45, y: 0.12, width: 0.16, height: 0.14)
            ],
            people: [
                CGRect(x: 0.02, y: 0.12, width: 0.18, height: 0.55),
                CGRect(x: 0.31, y: 0.05, width: 0.48, height: 0.9)
            ],
            imageSize: imageSize
        )

        XCTAssertEqual(analysis.result, .multiplePeople)
        XCTAssertGreaterThan(analysis.cardCrop.cgRect.midX, 0.35)
        XCTAssertLessThan(analysis.cardCrop.cgRect.midX, 0.7)
    }

    func testTwoPeopleWithoutFacesStillReportMultiplePeople() {
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [],
            people: [
                CGRect(x: 0.05, y: 0.18, width: 0.28, height: 0.7),
                CGRect(x: 0.4, y: 0.08, width: 0.5, height: 0.88)
            ],
            imageSize: CGSize(width: 1_200, height: 1_600)
        )

        XCTAssertEqual(analysis.result, .multiplePeople)
        XCTAssertGreaterThan(analysis.cardCrop.cgRect.midX, 0.4)
    }

    func testFaceOnlyPersonOnlyAndNoDetectionFallbacks() {
        let size = CGSize(width: 800, height: 1_200)
        XCTAssertEqual(
            PlayerPhotoFramingGeometry.analyze(
                faces: [CGRect(x: 0.4, y: 0.15, width: 0.2, height: 0.18)],
                people: [],
                imageSize: size
            ).result,
            .faceOnly
        )
        XCTAssertEqual(
            PlayerPhotoFramingGeometry.analyze(
                faces: [],
                people: [CGRect(x: 0.25, y: 0.08, width: 0.5, height: 0.86)],
                imageSize: size
            ).result,
            .personOnly
        )
        let fallback = PlayerPhotoFramingGeometry.analyze(faces: [], people: [], imageSize: size)
        XCTAssertEqual(fallback.result, .noUsableDetection)
        assertPhysicalAspect(fallback.cardCrop, imageSize: size, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
    }

    func testCenteredCropHandlesExtremeAspectRatios() {
        let panorama = CGSize(width: 4_000, height: 500)
        let tall = CGSize(width: 400, height: 3_000)
        let panoramaCrop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: panorama)
        let tallCrop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: tall)

        assertPhysicalAspect(panoramaCrop, imageSize: panorama, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        assertPhysicalAspect(tallCrop, imageSize: tall, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        XCTAssertEqual(panoramaCrop.cgRect.midX, 0.5, accuracy: 0.001)
        XCTAssertEqual(tallCrop.cgRect.midY, 0.5, accuracy: 0.001)
    }

    func testPreparationNormalizesOrientationAndBoundsMaster() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4_000, height: 2_000))
        let base = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4_000, height: 2_000))
        }
        guard let cgImage = base.cgImage,
              let encoded = UIImage(cgImage: cgImage, scale: 1, orientation: .left).jpegData(compressionQuality: 0.9) else {
            return XCTFail("Could not create oriented fixture")
        }

        let prepared = try await PlayerPhotoPreparationService().prepare(data: encoded)
        let decodedMaster = try XCTUnwrap(UIImage(data: prepared.masterJPEG))
        let decodedProfile = try XCTUnwrap(UIImage(data: prepared.profileJPEG))

        XCTAssertLessThanOrEqual(max(decodedMaster.size.width, decodedMaster.size.height), 3_000)
        XCTAssertEqual(decodedProfile.size, PlayerPhotoPreparationService.profilePixelSize)
        XCTAssertEqual(decodedMaster.imageOrientation, .up)
    }

    private func assertPhysicalAspect(
        _ crop: NormalizedPhotoCrop,
        imageSize: CGSize,
        expected: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = crop.cgRect.width * imageSize.width / (crop.cgRect.height * imageSize.height)
        XCTAssertEqual(actual, expected, accuracy: 0.002, file: file, line: line)
    }
}
