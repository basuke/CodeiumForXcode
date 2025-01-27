import AIModel
import ComposableArchitecture
import Dependencies
import Keychain
import OpenAIService
import Preferences
import SwiftUI

struct EmbeddingModelEdit: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var id: String
        @BindingState var name: String
        @BindingState var format: EmbeddingModel.Format
        @BindingState var maxTokens: Int = 8191
        @BindingState var modelName: String = ""
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var baseURL: String { baseURLSelection.baseURL }
        var availableModelNames: [String] = []
        var availableAPIKeys: [String] = []
        var isTesting = false
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case appear
        case saveButtonClicked
        case cancelButtonClicked
        case refreshAvailableModelNames
        case testButtonClicked
        case testSucceeded(String)
        case testFailed(String)
        case checkSuggestedMaxTokens
        case apiKeySelection(APIKeySelection.Action)
        case baseURLSelection(BaseURLSelection.Action)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Scope(state: \.apiKeySelection, action: /Action.apiKeySelection) {
            APIKeySelection()
        }

        Scope(state: \.baseURLSelection, action: /Action.baseURLSelection) {
            BaseURLSelection()
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.refreshAvailableModelNames)
                    await send(.checkSuggestedMaxTokens)
                }

            case .saveButtonClicked:
                return .none

            case .cancelButtonClicked:
                return .none

            case .testButtonClicked:
                guard !state.isTesting else { return .none }
                state.isTesting = true
                let model = EmbeddingModel(
                    id: state.id,
                    name: state.name,
                    format: state.format,
                    info: .init(
                        apiKeyName: state.apiKeyName,
                        baseURL: state.baseURL,
                        maxTokens: state.maxTokens,
                        modelName: state.modelName
                    )
                )
                return .run { send in
                    do {
                        let tokenUsage =
                            try await EmbeddingService(
                                configuration: UserPreferenceEmbeddingConfiguration()
                                    .overriding {
                                        $0.model = model
                                    }
                            ).embed(text: "Hello").usage.total_tokens
                        await send(.testSucceeded("Used \(tokenUsage) tokens."))
                    } catch {
                        await send(.testFailed(error.localizedDescription))
                    }
                }

            case let .testSucceeded(message):
                state.isTesting = false
                toast(message, .info)
                return .none

            case let .testFailed(message):
                state.isTesting = false
                toast(message, .error)
                return .none

            case .refreshAvailableModelNames:
                if state.format == .openAI {
                    state.availableModelNames = ChatGPTModel.allCases.map(\.rawValue)
                }

                return .none

            case .checkSuggestedMaxTokens:
                guard state.format == .openAI,
                      let knownModel = OpenAIEmbeddingModel(rawValue: state.modelName)
                else {
                    state.suggestedMaxTokens = nil
                    return .none
                }
                state.suggestedMaxTokens = knownModel.maxToken
                return .none

            case .apiKeySelection:
                return .none

            case .baseURLSelection:
                return .none

            case .binding(\.$format):
                return .run { send in
                    await send(.refreshAvailableModelNames)
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding(\.$modelName):
                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding:
                return .none
            }
        }
    }
}

extension EmbeddingModelEdit.State {
    init(model: EmbeddingModel) {
        self.init(
            id: model.id,
            name: model.name,
            format: model.format,
            maxTokens: model.info.maxTokens,
            modelName: model.info.modelName,
            apiKeySelection: .init(
                apiKeyName: model.info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [model.info.apiKeyName])
            ),
            baseURLSelection: .init(baseURL: model.info.baseURL)
        )
    }
}

extension EmbeddingModel {
    init(state: EmbeddingModelEdit.State) {
        self.init(
            id: state.id,
            name: state.name,
            format: state.format,
            info: .init(
                apiKeyName: state.apiKeyName,
                baseURL: state.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                maxTokens: state.maxTokens,
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }
}

