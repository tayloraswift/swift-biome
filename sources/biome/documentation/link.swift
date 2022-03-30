extension Documentation 
{
    @frozen public 
    enum ResolvedLink:Hashable, Sendable
    {
        case article(Int)
        case module(Int)
        case symbol(Int, victim:Int?, components:Int = .max)
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
        case entrapta(URI.Path, absolute:Bool)
        case docc([[UInt8]], Disambiguator.DocC?)
        
        var components:Int 
        {
            switch self 
            {
            case .preresolved(.symbol(_, victim: _, components: let components)): 
                return components 
            case .entrapta(let path, absolute: false): 
                return path.stem.count + (path.leaf.isEmpty ? 0 : 1)
            case .docc(let path, _): 
                return path.count 
            default: 
                return .max
            }
        }
    }
    struct UnresolvedLinkContext 
    {
        let whitelist:Set<Int>
        let greenzone:(namespace:Int, scope:[[UInt8]])?
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
        return .docc(Documentation.URI.normalize(path: path.utf8.split(separator: 0x2f)), suffix)
    }
    static 
    func entrapta<S>(normalizing string:S) -> Self 
        where S:StringProtocol, S.UTF8View.SubSequence == Substring.UTF8View
    {
        var ignored:Bool = true 
        if case 0x2f? = string.utf8.first
        {
            return .entrapta(.normalize(joined: string.utf8.dropFirst(), changed: &ignored), absolute: true)
        }
        else 
        {
            return .entrapta(.normalize(joined: string.utf8[...],        changed: &ignored), absolute: false)
        }
    }
    
    var description:String 
    {
        switch self 
        {
        case .preresolved(let resolved):
            return "preresolved (\(resolved))"
        case .entrapta(let path, absolute: _):
            return path.description
        case .docc(let path, let suffix?):
            return "\(String.init(decoding: Documentation.URI.concatenate(normalized: path), as: Unicode.UTF8.self)) \(suffix)"
        case .docc(let path, nil):
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
