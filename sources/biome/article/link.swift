@frozen public 
enum ResolvedLink:Hashable, Sendable
{
    case article(Int)
    case package(Int)
    case module(Int)
    case symbol(Int, victim:Int?, components:Int = .max)
}
enum UnresolvedLink:Hashable, CustomStringConvertible, Sendable
{
    struct Context
    {
        let whitelist:Set<Int>
        let greenzone:(namespace:Int, scope:[[UInt8]])?
    }
    enum Disambiguator 
    {
        enum DocC:Hashable, CustomStringConvertible 
        {
            case kind(Symbol.Kind)
            case hash(String)
        }
    }
    
    case preresolved(ResolvedLink)
    case entrapta(absolute:Bool, Documentation.URI.Path, count:Int)
    case docc([[UInt8]], Disambiguator.DocC?)
    
    var components:Int 
    {
        switch self 
        {
        case .preresolved(.symbol(_, victim: _, components: let components)): 
            return components 
        case .entrapta(absolute: false, let path, count: let count): 
            return count + (path.leaf.isEmpty ? 0 : 1)
        case .docc(let path, _): 
            return path.count 
        default: 
            return .max
        }
    }
}
extension UnresolvedLink 
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
        var whatever:Bool = true 
        let absolute:Bool 
        let path:(stem:[Substring.UTF8View], leaf:Substring.UTF8View)
        if case 0x2f? = string.utf8.first
        {
            absolute = true 
            path = Documentation.URI.Path.split(joined: string.utf8.dropFirst())
        }
        else 
        {
            absolute = false
            path = Documentation.URI.Path.split(joined: string.utf8[...])
        }
        var stem:[[UInt8]] = []
        var count:Int = 0 
        for component:Substring.UTF8View in path.stem 
        {
            if component.isEmpty 
            {
                count = 0 
            }
            else 
            {
                stem.append(Documentation.URI.normalize(component: component, changed: &whatever))
                count += 1
            }
        }
        return .entrapta(absolute: absolute, 
            Documentation.URI.Path.init(stem: stem, 
                leaf: Documentation.URI.normalize(component: path.leaf, changed: &whatever)), 
            count: count)
    }
    
    var description:String 
    {
        switch self 
        {
        case .preresolved(let resolved):
            return "preresolved (\(resolved))"
        case .entrapta(absolute: _, let path, count: _):
            return path.description
        case .docc(let path, let suffix?):
            return "\(String.init(decoding: Documentation.URI.concatenate(normalized: path), as: Unicode.UTF8.self)) \(suffix)"
        case .docc(let path, nil):
            return    String.init(decoding: Documentation.URI.concatenate(normalized: path), as: Unicode.UTF8.self)
        }
    }
}
extension UnresolvedLink.Disambiguator.DocC
{
    init(_ string:String)
    {
        self = Symbol.Kind.init(rawValue: string).map(Self.kind(_:)) ?? .hash(string)
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
