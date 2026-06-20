public struct LocalModelProfileID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct LocalModelProfile: Equatable, Sendable {
    public let id: LocalModelProfileID
    public let name: String
    public let isDownloaded: Bool
    public let isRemovable: Bool

    public init(id: LocalModelProfileID, name: String, isDownloaded: Bool = true, isRemovable: Bool = true) {
        self.id = id
        self.name = name
        self.isDownloaded = isDownloaded
        self.isRemovable = isRemovable
    }
}

public struct ModelInventory: Equatable, Sendable {
    public let downloadedProfiles: [LocalModelProfile]
    public let defaultProfileID: LocalModelProfileID?

    public init(downloadedProfiles: [LocalModelProfile], defaultProfileID: LocalModelProfileID?) {
        self.downloadedProfiles = downloadedProfiles
        self.defaultProfileID = defaultProfileID
    }
}

final class ModelInventoryStore {
    private var profilesByID: [LocalModelProfileID: LocalModelProfile] = [:]
    private var profileOrder: [LocalModelProfileID] = []
    private var defaultProfileID: LocalModelProfileID?
    private var adapterProfileIDs: Set<LocalModelProfileID> = []

    func record(_ profile: LocalModelProfile) -> LocalModelProfile {
        if profilesByID[profile.id] == nil {
            profileOrder.append(profile.id)
        }
        profilesByID[profile.id] = profile
        adapterProfileIDs.remove(profile.id)
        return profile
    }

    func replaceAdapterSourcedInventory(_ inventory: ModelInventory) -> ModelInventory {
        let shouldPreserveManualDefault = defaultProfileID.map {
            !adapterProfileIDs.contains($0) && profilesByID[$0]?.isDownloaded == true
        } == true

        for profileID in adapterProfileIDs {
            profilesByID[profileID] = nil
        }
        profileOrder.removeAll { adapterProfileIDs.contains($0) }
        adapterProfileIDs.removeAll()

        let downloadedProfiles = inventory.downloadedProfiles.filter(\.isDownloaded)
        for profile in downloadedProfiles {
            if profilesByID[profile.id] != nil, !adapterProfileIDs.contains(profile.id) {
                continue
            }
            if profilesByID[profile.id] == nil {
                profileOrder.append(profile.id)
            }
            profilesByID[profile.id] = profile
            adapterProfileIDs.insert(profile.id)
        }

        let downloadedProfileIDs = Set(self.downloadedProfiles().map(\.id))
        if shouldPreserveManualDefault {
            // Keep the user's explicit manual default over host-reported defaults.
        } else if let requestedDefaultProfileID = inventory.defaultProfileID,
           downloadedProfileIDs.contains(requestedDefaultProfileID) {
            defaultProfileID = requestedDefaultProfileID
        } else if defaultProfileID.map({ profilesByID[$0]?.isDownloaded == true }) != true {
            defaultProfileID = nil
        }

        return self.inventory()
    }

    func inventory() -> ModelInventory {
        ModelInventory(
            downloadedProfiles: downloadedProfiles(),
            defaultProfileID: defaultProfileID
        )
    }

    func chosenProfile() -> LocalModelProfile? {
        if let defaultProfileID, let profile = profilesByID[defaultProfileID], profile.isDownloaded {
            return profile
        }

        return downloadedProfiles().first
    }

    func setDefault(profileID: LocalModelProfileID) throws -> ModelInventory {
        guard profilesByID[profileID]?.isDownloaded == true else {
            throw RuntimeError.localModelProfileNotFound(profileID)
        }

        defaultProfileID = profileID
        return inventory()
    }

    func clearDefault() -> ModelInventory {
        defaultProfileID = nil
        return inventory()
    }

    func remove(profileID: LocalModelProfileID) throws -> ModelInventory {
        guard let profile = profilesByID[profileID] else {
            throw RuntimeError.localModelProfileNotFound(profileID)
        }
        guard profile.isRemovable else {
            throw RuntimeError.localModelProfileNotRemovable(profileID)
        }

        profilesByID[profileID] = nil
        profileOrder.removeAll { $0 == profileID }
        adapterProfileIDs.remove(profileID)

        if defaultProfileID == profileID {
            defaultProfileID = nil
        }

        return inventory()
    }

    private func downloadedProfiles() -> [LocalModelProfile] {
        profileOrder.compactMap { profilesByID[$0] }.filter(\.isDownloaded)
    }
}
