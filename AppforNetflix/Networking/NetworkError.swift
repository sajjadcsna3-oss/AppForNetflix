import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case server(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            L10n.string("The server returned an unexpected response.")
        case .server(let code):
            L10n.format("network_server_error_format", languageCode: nil, code)
        case .decoding:
            L10n.string("Couldn't read the data we received.")
        }
    }
}
