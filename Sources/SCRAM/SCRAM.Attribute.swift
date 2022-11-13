extension SCRAM
{
    @frozen public
    struct Attribute:Hashable, RawRepresentable, Sendable
    {
        public
        let rawValue:Unicode.Scalar

        @inlinable public
        init(rawValue:Unicode.Scalar)
        {
            self.rawValue = rawValue
        }
    }
}
extension SCRAM.Attribute
{
    /// Authorization identity ([`'a'`]()).
    public static
    let authorization:Self = .init(rawValue: "a")

    /// GS2 header and channel binding data ([`'c'`]()).
    public static
    let channel:Self = .init(rawValue: "c")

    /// Error ([`'e'`]()).
    public static
    let error:Self = .init(rawValue: "e")

    /// Iteration count ([`'s'`]()).
    public static
    let iterations:Self = .init(rawValue: "i")

    /// Mandatory extension ([`'m'`]()).
    public static
    let mandatoryExtension:Self = .init(rawValue: "m")

    /// Name ([`'n'`]()).
    public static
    let name:Self = .init(rawValue: "n")

    /// Client proof ([`'p'`]()).
    public static
    let proof:Self = .init(rawValue: "p")

    /// Random nonce ([`'r'`]()).
    public static
    let random:Self = .init(rawValue: "r")

    /// Salt ([`'s'`]()).
    public static
    let salt:Self = .init(rawValue: "s")

    /// Server verification signature ([`'v'`]()).
    public static
    let verification:Self = .init(rawValue: "v")
}
extension SCRAM.Attribute:CustomStringConvertible
{
    public
    var description:String
    {
        .init(self.rawValue)
    }
}
