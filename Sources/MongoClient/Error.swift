internal struct OptionalUnwrapFailure: Error, CustomStringConvertible {
    let description = "An optional was unwrapped but `nil` was found"
}

/// A reply from the server, indicating an error
public struct MongoGenericErrorReply: Error, Codable, Equatable {
    public let ok: Int
    public let errorMessage: String?
    public let code: Int?
    public let codeName: String?

    private enum CodingKeys: String, CodingKey {
        case ok, code, codeName
        case errorMessage = "errmsg"
    }
}
