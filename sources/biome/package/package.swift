import Resource

public 
struct Package:Sendable, Identifiable
{
    /// A globally-unique index referencing a package. 
    struct Index 
    {
        let bits:UInt16
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(offset:Int)
        {
            self.bits = .init(offset)
        }
    }
    
    public 
    struct ID:Hashable, Comparable, Sendable, Decodable, ExpressibleByStringLiteral, CustomStringConvertible
    {
        public 
        enum Kind:Hashable, Comparable, Sendable 
        {
            case swift 
            case community(String)
        }
        
        @usableFromInline
        let kind:Kind 
        
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.kind < rhs.kind
        }
        
        public static 
        let swift:Self = .init(kind: .swift)
        
        public 
        var string:String 
        {
            switch self.kind
            {
            case .swift:                return "swift-standard-library"
            case .community(let name):  return name 
            }
        }
        public 
        var description:String 
        {
            switch self.kind
            {
            case .swift:                return "(swift)"
            case .community(let name):  return name 
            }
        }
        
        @inlinable public 
        init(from decoder:any Decoder) throws 
        {
            self.init(try decoder.decode(String.self))
        }
        public 
        init(stringLiteral:String)
        {
            self.init(stringLiteral)
        }
        @inlinable public
        init<S>(_ string:S) where S:StringProtocol
        {
            switch string.lowercased() 
            {
            case    "swift-standard-library",
                    "standard-library",
                    "swift-stdlib",
                    "stdlib":
                self.init(kind: .swift)
            case let name:
                self.init(kind: .community(name))
            }
        }
        
        @inlinable public 
        init(kind:Kind)
        {
            self.kind = kind
        }
        
        @available(*, deprecated)
        var root:[UInt8]
        {
            Documentation.URI.encode(component: self.name.utf8)
        }
        
        @available(*, deprecated, renamed: "string")
        public 
        var name:String 
        {
            self.string 
        }
    }
    public 
    struct Catalog<Location>
    {
        public 
        let id:ID 
        public 
        let modules:[Module.Catalog<Location>]
    }
    
    public 
    enum Version:CustomStringConvertible, Sendable
    {
        case date(year:Int, month:Int, day:Int)
        case tag(major:Int, (minor:Int, (patch:Int, edition:Int?)?)?)
        
        public 
        var description:String 
        {
            switch self
            {
            case .date(year: let year, month: let month, day: let day):
                // not zero-padded, and probably unsuitable for generating 
                // links to toolchains.
                return "\(year)-\(month)-\(day)"
            case .tag(major: let major, nil):
                return "\(major)"
            case .tag(major: let major, (minor: let minor, nil)?):
                return "\(major).\(minor)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: nil)?)?):
                return "\(major).\(minor).\(patch)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: let edition?)?)?):
                return "\(major).\(minor).\(patch).\(edition)"
            }
        }
    }
    
    /* struct Dependency
    {
        let package:Int 
        let imports:[Int]
    }  */
    
    public 
    let id:ID
    private 
    var hash:Resource.Version?
    private(set)
    var modules:[Module], 
        symbols:[Symbol]
    
    private(set)
    var indices:
    (
        modules:[Module.ID: Module.Index],
        symbols:[Symbol.ID: Symbol.Index]
    )
    
    var name:String 
    {
        self.id.name
    }
    
    init(id:ID, indices:
        (
            modules:[Module.ID: Module.Index],
            symbols:[Symbol.ID: Symbol.Index]
        ), 
        modules:[Module], 
        symbols:[Symbol], 
        hash:Resource.Version?)
    {
        self.id = id
        self.hash = hash
        self.indices = indices
        self.modules = modules
        self.symbols = symbols
    }
}

extension Module 
{
    struct Scope 
    {
        //  the endpoints of a graph edge can reference symbols in either this 
        //  package or one of its dependencies. since imports are module-wise, and 
        //  not package-wise, it’s possible for multiple index dictionaries to 
        //  return matches, as long as only one of them belongs to an depended-upon module.
        //  
        //  it’s also possible to prefer a dictionary result in a foreign package over 
        //  a dictionary result in the local package, if the foreign package contains 
        //  a module that shadows one of the modules in the local package (as long 
        //  as the target itself does not also depend upon the shadowed local module.)
        private 
        let filter:Set<Module.Index>
        private 
        let layers:[[Symbol.ID: Symbol.Index]]
        
        init(filter:Set<Module.Index>, layers:[[Symbol.ID: Symbol.Index]])
        {
            self.filter = filter 
            self.layers = layers 
        }
        
        func index(of symbol:Symbol.ID) throws -> Symbol.Index 
        {
            if let index:Symbol.Index = self[symbol]
            {
                return index 
            }
            else 
            {
                throw SymbolError.undefined(id: symbol)
            } 
        }
        private 
        subscript(symbol:Symbol.ID) -> Symbol.Index?
        {
            for layer:Int in self.layers.indices
            {
                guard let index:Symbol.Index = self.layers[layer][symbol], 
                    self.filter.contains(index.module)
                else 
                {
                    continue 
                }
                // sanity check: ensure none of the remaining layers contains 
                // a colliding symbol 
                for layer:[Symbol.ID: Symbol.Index] in self.layers[layer...].dropFirst()
                {
                    if case _? = layer[symbol], self.filter.contains(index.module)
                    {
                        fatalError("colliding symbol identifiers in search space")
                    }
                }
                return index
            }
        }
    }
}
