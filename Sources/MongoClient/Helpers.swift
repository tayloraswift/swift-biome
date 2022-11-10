import Foundation

extension String {
    /// Decodes a base64 string into another String
    func base64Decoded() throws -> String {
        guard
            let data = Data(base64Encoded: self),
            let string = String(data: data, encoding: .utf8)
        else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }

        return string
    }
}
