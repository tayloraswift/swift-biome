import Base64

extension SCRAM
{
    @frozen public
    struct Message:Sendable
    {
        public
        let string:String

        public
        init(_ string:String)
        {
            self.string = string
        }
    }
}
extension SCRAM.Message:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.string
    }
}
extension SCRAM.Message
{
    @inlinable public
    init(base64:some Sequence<UInt8>)
    {
        self.init(.init(decoding: Base64.decode(base64, to: [UInt8].self),
            as: Unicode.UTF8.self))
    }
    @inlinable public
    var base64:String
    {
        Base64.encode(self.string.utf8)
    }
}

extension SCRAM.Message
{
    @usableFromInline
    func fields() -> [(key:SCRAM.Attribute, value:Substring)]
    {
        self.string.split(separator: ",").compactMap
        {
            if  let index:String.Index = $0.index($0.startIndex, offsetBy: 2,
                    limitedBy: $0.endIndex)
            {
                let key:SCRAM.Attribute = .init(rawValue: $0.unicodeScalars[$0.startIndex])
                return (key, $0[index...])
            }
            else
            {
                return nil
            }
        }
    }
}
