@frozen public
struct SymbolIdentifier:Hashable, Sendable 
{
    @frozen public 
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }

    public 
    let string:String 
    
    init(unchecked:String)
    {
        self.string = unchecked
    }
    @inlinable public 
    init<ASCII>(_ language:Language, _ mangled:ASCII) where ASCII:Collection, ASCII.Element == UInt8 
    {
        self.string = "\(language.rawValue)\(String.init(decoding: mangled, as: Unicode.ASCII.self))"
    }
    
    @inlinable public 
    var language:Language 
    {
        guard let language:Language = self.string.unicodeScalars.first.flatMap(Language.init(rawValue:))
        else 
        {
            // should always be round-trippable
            fatalError("unreachable")
        }
        return language 
    }
}
extension SymbolIdentifier:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.string
    }
}