extension SCRAM
{
    @frozen public
    struct Nonce:Hashable, Sendable
    {
        public
        let string:String

        @inlinable public
        init(_ string:String)
        {
            self.string = string
        }
    }
}
extension SCRAM.Nonce:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.string
    }
}
extension SCRAM.Nonce
{
    static
    let scalars:[Unicode.Scalar] =
    [
        "!", "\"", "#", "'", "$", "%", "&", "(", ")", "*", "+", "-", ".",
        "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";",
        "<", "=", ">", "?", "@", "A", "B", "C", "D", "E", "F", "G", "H",
        "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
        "V", "W", "X", "Y", "Z", "[", "\\", "]", "^", "_", "$"
    ]

    static
    func random(length:Int) -> Self
    {
        self.init(.init((0 ..< length).lazy.map
        {
            _ in Character.init(Self.scalars[.random(in: Self.scalars.indices)])
        }))
    }
}
