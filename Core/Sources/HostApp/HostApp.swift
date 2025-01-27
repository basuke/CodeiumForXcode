import Client
import ComposableArchitecture
import Foundation

#if canImport(LicenseManagement)
import LicenseManagement
#endif

struct HostApp: ReducerProtocol {
    struct State: Equatable {
        var general = General.State()
        var chatModelManagement = ChatModelManagement.State()
        var embeddingModelManagement = EmbeddingModelManagement.State()
    }

    enum Action: Equatable {
        case appear
        case informExtensionServiceAboutLicenseKeyChange
        case general(General.Action)
        case chatModelManagement(ChatModelManagement.Action)
        case embeddingModelManagement(EmbeddingModelManagement.Action)
    }

    @Dependency(\.toast) var toast

    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.general, action: /Action.general) {
            General()
        }
        
        Scope(state: \.chatModelManagement, action: /Action.chatModelManagement) {
            ChatModelManagement()
        }
        
        Scope(state: \.embeddingModelManagement, action: /Action.embeddingModelManagement) {
            EmbeddingModelManagement()
        }

        Reduce { _, action in
            switch action {
            case .appear:
                return .none
                
            case .informExtensionServiceAboutLicenseKeyChange:
                #if canImport(LicenseManagement)
                return .run { _ in
                    let service = try getService()
                    do {
                        try await service
                            .postNotification(name: Notification.Name.licenseKeyChanged.rawValue)
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                }
                #else
                return .none
                #endif
                
            case .general:
                return .none
                
            case .chatModelManagement:
                return .none
                
            case .embeddingModelManagement:
                return .none
            }
        }
    }
}

import Dependencies
import Preferences
import Keychain

struct UserDefaultsDependencyKey: DependencyKey {
    static var liveValue: UserDefaultsType = UserDefaults.shared
    static var previewValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppPreview")!
        it.removePersistentDomain(forName: "HostAppPreview")
        return it
    }()
    static var testValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppTest")!
        it.removePersistentDomain(forName: "HostAppTest")
        return it
    }()
}

extension DependencyValues {
    var userDefaults: UserDefaultsType {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }
}

struct APIKeyKeychainDependencyKey: DependencyKey {
    static var liveValue: KeychainType = Keychain.apiKey
    static var previewValue: KeychainType = FakeKeyChain()
    static var testValue: KeychainType = FakeKeyChain()
}

extension DependencyValues {
    var apiKeyKeychain: KeychainType {
        get { self[APIKeyKeychainDependencyKey.self] }
        set { self[APIKeyKeychainDependencyKey.self] = newValue }
    }
}
