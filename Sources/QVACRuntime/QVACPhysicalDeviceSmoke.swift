public struct QVACPhysicalDeviceSmokeEnvironment: Equatable, Codable, Sendable {
    public let platform: QVACPhysicalDeviceSmokePlatform
    public let executionTarget: QVACPhysicalDeviceSmokeExecutionTarget
    public let majorIOSVersion: Int
    public let requiresLocalOnlyExecution: Bool
    public let requiresAppStorePublication: Bool
    public let hostPath: QVACPhysicalDeviceSmokeHostPath

    public init(
        platform: QVACPhysicalDeviceSmokePlatform,
        executionTarget: QVACPhysicalDeviceSmokeExecutionTarget,
        majorIOSVersion: Int,
        requiresLocalOnlyExecution: Bool,
        requiresAppStorePublication: Bool,
        hostPath: QVACPhysicalDeviceSmokeHostPath
    ) {
        self.platform = platform
        self.executionTarget = executionTarget
        self.majorIOSVersion = majorIOSVersion
        self.requiresLocalOnlyExecution = requiresLocalOnlyExecution
        self.requiresAppStorePublication = requiresAppStorePublication
        self.hostPath = hostPath
    }
}

public enum QVACPhysicalDeviceSmokePlatform: String, Equatable, Codable, Sendable {
    case iOS
}

public enum QVACPhysicalDeviceSmokeExecutionTarget: String, Equatable, Codable, Sendable {
    case physicalDevice
    case simulator
    case emulator
}

public enum QVACPhysicalDeviceSmokeHostPath: String, Equatable, Codable, Sendable {
    case embeddedExpoBareRuntime
    case nativeBinding
    case otherApprovedLocalOnlyHost
}

public enum QVACPhysicalDeviceSmokeStatus: String, Equatable, Codable, Sendable {
    case validatedOnPhysicalDevice
    case blockedPendingPhysicalDeviceRun
}

public enum QVACPhysicalDeviceSmokeRejection: String, Equatable, Codable, Sendable {
    case physicalIOSDeviceRequired
    case minimumIOS17Required
    case localOnlyExecutionRequired
    case developmentInstallMustNotRequireAppStorePublication
    case nonEmptyGeneratedTextRequired
    case offlineRepeatabilityCheckRequired
}

public struct QVACPhysicalDeviceSmokePrerequisiteValidation: Equatable, Codable, Sendable {
    public let status: QVACPhysicalDeviceSmokeStatus
    public let rejections: [QVACPhysicalDeviceSmokeRejection]

    public init(status: QVACPhysicalDeviceSmokeStatus, rejections: [QVACPhysicalDeviceSmokeRejection]) {
        self.status = status
        self.rejections = rejections
    }
}

public struct QVACPhysicalDeviceSmokeModelProfile: Equatable, Codable, Sendable {
    public let identifier: String
    public let name: String
    public let source: String

    public init(identifier: String, name: String, source: String) {
        self.identifier = identifier
        self.name = name
        self.source = source
    }
}

public struct QVACPhysicalDeviceSmokeResult: Equatable, Codable, Sendable {
    public let status: QVACPhysicalDeviceSmokeStatus
    public let hostPath: QVACPhysicalDeviceSmokeHostPath
    public let modelProfile: QVACPhysicalDeviceSmokeModelProfile
    public let generatedTextNonEmpty: Bool
    public let offlineRepeatabilityChecked: Bool
    public let rejections: [QVACPhysicalDeviceSmokeRejection]

    public init(
        status: QVACPhysicalDeviceSmokeStatus,
        hostPath: QVACPhysicalDeviceSmokeHostPath,
        modelProfile: QVACPhysicalDeviceSmokeModelProfile,
        generatedTextNonEmpty: Bool,
        offlineRepeatabilityChecked: Bool,
        rejections: [QVACPhysicalDeviceSmokeRejection]
    ) {
        self.status = status
        self.hostPath = hostPath
        self.modelProfile = modelProfile
        self.generatedTextNonEmpty = generatedTextNonEmpty
        self.offlineRepeatabilityChecked = offlineRepeatabilityChecked
        self.rejections = rejections
    }
}

public enum QVACPhysicalDeviceSmokePlan {
    public static func validatePrerequisites(
        _ environment: QVACPhysicalDeviceSmokeEnvironment
    ) -> QVACPhysicalDeviceSmokePrerequisiteValidation {
        var rejections: [QVACPhysicalDeviceSmokeRejection] = []

        if environment.executionTarget != .physicalDevice {
            rejections.append(.physicalIOSDeviceRequired)
        }
        if environment.majorIOSVersion < 17 {
            rejections.append(.minimumIOS17Required)
        }
        if !environment.requiresLocalOnlyExecution {
            rejections.append(.localOnlyExecutionRequired)
        }
        if environment.requiresAppStorePublication {
            rejections.append(.developmentInstallMustNotRequireAppStorePublication)
        }

        return QVACPhysicalDeviceSmokePrerequisiteValidation(
            status: rejections.isEmpty ? .validatedOnPhysicalDevice : .blockedPendingPhysicalDeviceRun,
            rejections: rejections
        )
    }

    public static func recordResult(
        environment: QVACPhysicalDeviceSmokeEnvironment,
        modelProfile: QVACPhysicalDeviceSmokeModelProfile,
        generatedText: String,
        offlineRepeatabilityChecked: Bool
    ) -> QVACPhysicalDeviceSmokeResult {
        var rejections = validatePrerequisites(environment).rejections
        let generatedTextNonEmpty = !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if !generatedTextNonEmpty {
            rejections.append(.nonEmptyGeneratedTextRequired)
        }
        if !offlineRepeatabilityChecked {
            rejections.append(.offlineRepeatabilityCheckRequired)
        }
        return QVACPhysicalDeviceSmokeResult(
            status: rejections.isEmpty ? .validatedOnPhysicalDevice : .blockedPendingPhysicalDeviceRun,
            hostPath: environment.hostPath,
            modelProfile: modelProfile,
            generatedTextNonEmpty: generatedTextNonEmpty,
            offlineRepeatabilityChecked: offlineRepeatabilityChecked,
            rejections: rejections
        )
    }
}
