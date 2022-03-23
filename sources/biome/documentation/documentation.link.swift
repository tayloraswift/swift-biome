extension Documentation 
{
    enum ResolvedLink:Hashable, Sendable
    {
        case article(Int)
        case module(Int)
        case symbol(Int, victim:Int?)
    }

    enum UnresolvedLink:Hashable, CustomStringConvertible, Sendable
    {
        enum Disambiguator 
        {
            enum DocC:Hashable, CustomStringConvertible 
            {
                case kind(Biome.Symbol.Kind)
                case hash(String)
            }
        }
        
        case preresolved(ResolvedLink)
        case docc(doc:[[UInt8]], Disambiguator.DocC?)
    }
    struct UnresolvedLinkContext 
    {
        let namespace:Int 
        var scope:[[UInt8]]
    }
}
extension Documentation.UnresolvedLink 
{
    static 
    func docc<S>(normalizing string:S) -> Self 
        where S:StringProtocol, S.SubSequence == Substring
    {
        let path:Substring, 
            suffix:Disambiguator.DocC?
        if let hyphen:String.Index = string.firstIndex(of: "-") 
        {
            path    = string[..<hyphen]
            suffix  = .init(String.init(string[string.index(after: hyphen)...]))
        }
        else 
        {
            path    = string[...]
            suffix  = nil
        }
        // split on slashes
        return .docc(doc: Documentation.URI.normalize(path: path.utf8.split(separator: 0x2f)), suffix)
    }
    
    var description:String 
    {
        switch self 
        {
        case .preresolved(let resolved):
            return "preresolved (\(resolved))"
        case .docc(doc: let path, let suffix?):
            return "\(String.init(decoding: Documentation.URI.concatenate(normalized: path), as: Unicode.UTF8.self)) \(suffix)"
        case .docc(doc: let path, nil):
            return    String.init(decoding: Documentation.URI.concatenate(normalized: path), as: Unicode.UTF8.self)
        }
    }
}
extension Documentation.UnresolvedLink.Disambiguator.DocC
{
    init(_ string:String)
    {
        self = Biome.Symbol.Kind.init(rawValue: string).map(Self.kind(_:)) ?? .hash(string)
    }
    
    var description:String 
    {
        switch self 
        {
        case .kind(let kind):   return "(\(kind.rawValue))"
        case .hash(let hash):   return "(hash: \(hash))"
        }
    }
}
