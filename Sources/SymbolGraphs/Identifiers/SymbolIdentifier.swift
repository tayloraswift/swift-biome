@frozen public
struct SymbolIdentifier:Sendable 
{
    @frozen public 
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }

    // this must always be an ASCII string
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
extension SymbolIdentifier:Equatable
{
    @inlinable public static
    func == (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.string.utf8.elementsEqual(rhs.string.utf8)
    }
}
extension SymbolIdentifier:Hashable 
{
    @inlinable public 
    func hash(into hasher:inout Hasher) 
    {
        for byte:UInt8 in self.string.utf8
        {
            byte.hash(into: &hasher)
        }
    }
}
extension SymbolIdentifier:Comparable
{
    @inlinable public static
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.string.utf8.lexicographicallyPrecedes(rhs.string.utf8)
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