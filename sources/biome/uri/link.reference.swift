import Grammar

extension Link 
{
    struct Reference<Path>:BidirectionalCollection 
        where Path:BidirectionalCollection, Path.Element == Component
    {
        var path:Path
        var query:Query
        var orientation:Route.Orientation
        
        var startIndex:Path.Index 
        {
            self.path.startIndex
        }
        var endIndex:Path.Index 
        {
            self.path.endIndex
        }
        subscript(index:Path.Index) -> Component 
        {
            _read 
            {
                yield self.path[index]
            }
        }
        subscript(bounds:Range<Path.Index>) -> Reference<Path.SubSequence>
        {
            .init(path: self.path[bounds], query: self.query, orientation: self.orientation)
        }
        func index(before index:Path.Index) -> Path.Index 
        {
            self.path.index(before: index)
        }
        func index(after index:Path.Index) -> Path.Index 
        {
            self.path.index(after: index)
        }
        
        // it’s possible to get an empty path even though the URI is guaranteed non-empty
        // for example, we could have `/foo/..`, which would generate `[]`.
        // a path with one single component should default to ``straight``.
        init(path:Path, query:Query = .init(), orientation:Route.Orientation = .straight)
        {
            self.path = path 
            self.query = query 
            self.orientation = orientation
        }
        
        var nation:Package.ID? 
        {
            self.path.first?.identifier.map(Package.ID.init(_:))
        }
        var arrival:Version? 
        {
            self.path.first?.version ?? nil
        }
        var namespace:Module.ID? 
        {
            guard case .identifier(let module, hyphen: nil)? = self.path.first
            else 
            {
                return nil
            }
            return .init(module)
        }
        
        var disambiguator:Disambiguator 
        {
            .init(host: self.query.host, 
                symbol: self.query.symbol, 
                suffix: self.path.last?.suffix ?? nil)
        }
        
        var outed:Self? 
        {
            switch self.orientation 
            {
            case .gay: 
                return nil 
            case .straight: 
                return .init(path: self.path, query: self.query, orientation: .gay)
            }
        }
    }
    
    struct Query 
    {
        var symbol:Symbol.ID?
        var host:Symbol.ID?
        var lens:(culture:Package.ID, version:Version?)?
        
        init() 
        {
            self.symbol = nil 
            self.host = nil
            self.lens = nil 
        }
        
        mutating 
        func update(normalizing parameters:[URI.Parameter]) throws 
        {
            for (key, value):(String, String) in parameters 
            {
                switch key
                {
                case "from":
                    // either 'from=swift-foo' or 'from=swift-foo/0.1.2'. 
                    // we do not tolerate missing slashes
                    let components:[Substring] = value.split(separator: "/")
                    guard let first:Substring = components.first
                    else 
                    {
                        continue  
                    }
                    let id:Package.ID = .init(first)
                    if  let second:Substring = components.dropFirst().first, 
                        let version:Version = try? Grammar.parse(second.unicodeScalars, 
                            as: Version.Rule<String.Index>.self)
                    {
                        self.lens = (id, version)
                    }
                    else 
                    {
                        self.lens = (id, nil)
                    }
                
                case "self":
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.host  = try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.OpaqueName.self)
                
                case "overload": 
                    switch         try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.self) 
                    {
                    case .natural(let symbol):
                        self.symbol = symbol
                    
                    case .synthesized(from: let symbol, for: let host):
                        // this is supported for backwards-compatibility, 
                        // but the `::SYNTHESIZED::` infix is deprecated, 
                        // so this will end up causing a redirect 
                        self.host = host
                        self.symbol = symbol 
                    }

                default: 
                    continue  
                }
            }
        }
    }
}
extension Link.Reference where Path:RangeReplaceableCollection 
{
    mutating 
    func append(_ nation:Package.ID) 
    {
        // already guaranteed to be lowercased
        self.path.append(.identifier(nation.string))
    }
    mutating 
    func append(_ arrival:Version) 
    {
        self.path.append(.version(arrival))
    }
    mutating 
    func append(_ namespace:Module.ID) 
    {
        self.path.append(.identifier(namespace.value))
    }
    mutating 
    func append<Component>(lowercasing component:Component) 
        where Component:StringProtocol
    {
        self.path.append(.identifier(component.lowercased()))
    }
    mutating 
    func append<Components>(lowercasing components:Components)
        where Components:Sequence, Components.Element:StringProtocol
    {
        for component:Components.Element in components 
        {
            self.append(lowercasing: component)
        }
    }
}
