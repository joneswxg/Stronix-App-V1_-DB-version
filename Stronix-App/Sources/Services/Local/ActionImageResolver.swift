import Foundation

enum ActionImageResolution: Equatable {
    case mapped(resourcePath: String)
    case missingMapping
}

struct ActionImageResolver {
    private let mappingsByActionID: [Int: ManifestMapping]

    init(manifestData: Data) {
        guard
            let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData),
            manifest.schemaVersion == 1,
            manifest.mappings.allSatisfy({ $0.isValid }),
            Set(manifest.mappings.map(\.actionID)).count == manifest.mappings.count
        else {
            mappingsByActionID = [:]
            return
        }

        mappingsByActionID = Dictionary(
            uniqueKeysWithValues: manifest.mappings.map { ($0.actionID, $0) }
        )
    }

    init(bundle: Bundle = .main) {
        guard
            let url = bundle.url(forResource: "action_images", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            self.init(manifestData: Data())
            return
        }

        self.init(manifestData: data)
    }

    func resolve(actionID: Int, externalID: String) -> ActionImageResolution {
        guard let mapping = mappingsByActionID[actionID], mapping.externalID == externalID else {
            return .missingMapping
        }

        return .mapped(resourcePath: mapping.resourcePath)
    }
}

private struct Manifest: Decodable {
    let schemaVersion: Int
    let mappings: [ManifestMapping]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case mappings
    }
}

private struct ManifestMapping: Decodable {
    let actionID: Int
    let externalID: String
    let resourcePath: String

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case externalID = "external_id"
        case resourcePath = "resource_path"
    }

    var isValid: Bool {
        actionID > 0
            && !externalID.isEmpty
            && resourcePath.hasPrefix("Images/")
            && resourcePath.hasSuffix(".gif")
            && !resourcePath.contains("..")
    }
}
