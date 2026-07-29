import XCTest
@testable import Stronix

final class ActionImageResolverTests: XCTestCase {
    func testResolveReturnsExactManifestPathForMatchingActionIdentity() {
        let resolver = ActionImageResolver(manifestData: manifestData())

        let resolution = resolver.resolve(actionID: 2, externalID: "1256")

        XCTAssertEqual(resolution, .mapped(resourcePath: "Images/triceps/exercise_1256.gif"))
    }

    func testResolveReturnsMissingMappingForUnknownAction() {
        let resolver = ActionImageResolver(manifestData: manifestData())

        XCTAssertEqual(resolver.resolve(actionID: 999, externalID: "999"), .missingMapping)
    }

    func testResolveReturnsMissingMappingForExternalIDMismatch() {
        let resolver = ActionImageResolver(manifestData: manifestData())

        XCTAssertEqual(resolver.resolve(actionID: 2, externalID: "wrong"), .missingMapping)
    }

    func testResolveReturnsMissingMappingForInvalidManifest() {
        let resolver = ActionImageResolver(manifestData: Data("not json".utf8))

        XCTAssertEqual(resolver.resolve(actionID: 2, externalID: "1256"), .missingMapping)
    }

    func testBundledManifestResolvesKnownAction() {
        let resolver = ActionImageResolver(bundle: Bundle(for: ActionListViewModel.self))

        XCTAssertEqual(
            resolver.resolve(actionID: 2, externalID: "1256"),
            .mapped(resourcePath: "Images/triceps/exercise_1256.gif")
        )
    }

    func testResourceLocatorFindsExactBundledPath() {
        let locator = ActionImageResourceLocator(bundle: Bundle(for: ActionListViewModel.self))

        XCTAssertNotNil(locator.bundledGIFURL(for: "Images/triceps/exercise_1256.gif"))
    }

    func testResourceLocatorFindsBundledImageByFilename() {
        let locator = ActionImageResourceLocator(bundle: Bundle(for: ActionListViewModel.self))

        XCTAssertNotNil(locator.bundledGIFURL(for: "exercise_1256.gif"))
    }

    func testResourceLocatorReturnsNilForMissingImage() {
        let locator = ActionImageResourceLocator(bundle: Bundle(for: ActionListViewModel.self))

        XCTAssertNil(locator.bundledGIFURL(for: "missing_action.gif"))
    }

    func testGIFThumbnailUsesDownsampledFirstFrame() throws {
        let locator = ActionImageResourceLocator(bundle: Bundle(for: ActionListViewModel.self))
        let url = try XCTUnwrap(locator.bundledGIFURL(for: "Images/triceps/exercise_1256.gif"))

        let thumbnail = try XCTUnwrap(
            GIFThumbnailImageView.createThumbnail(from: url, maximumPixelSize: 150, scale: 3)
        )

        XCTAssertLessThanOrEqual(thumbnail.cgImage?.width ?? .max, 150)
        XCTAssertLessThanOrEqual(thumbnail.cgImage?.height ?? .max, 150)
        XCTAssertNil(thumbnail.images)
    }

    func testImageDecoderReturnsNilForEmptyData() {
        XCTAssertNil(ActionImageDecoder.image(from: Data()))
    }

    func testImageDecoderReturnsNilForNonImageData() {
        XCTAssertNil(ActionImageDecoder.image(from: Data("not an image".utf8)))
    }

    private func manifestData() -> Data {
        Data(
            """
            {
              "schema_version": 1,
              "mappings": [
                {
                  "action_id": 2,
                  "external_id": "1256",
                  "resource_path": "Images/triceps/exercise_1256.gif"
                }
              ]
            }
            """.utf8
        )
    }
}
