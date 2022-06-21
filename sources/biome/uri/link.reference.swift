import Grammar

extension Link 
{
    struct Reference<Path>:BidirectionalCollection where Path:BidirectionalCollection
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
        subscript(index:Path.Index) -> Path.Element
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
        static 
        let base:String = "overload", 
            host:String = "self", 
            lens:String = "from"
        
        var base:Symbol.ID?
        var host:Symbol.ID?
        var lens:(culture:Package.ID, version:MaskedVersion?)?
        
        init() 
        {
            self.base = nil 
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
                case Self.lens:
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
                        let version:MaskedVersion = try? Grammar.parse(second.unicodeScalars, 
                            as: MaskedVersion.Rule<String.Index>.self)
                    {
                        self.lens = (id, version)
                    }
                    else 
                    {
                        self.lens = (id, nil)
                    }
                
                case Self.host:
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.host  = try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.OpaqueName.self)
                
                case Self.base: 
                    switch         try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.self) 
                    {
                    case .natural(let base):
                        self.base = base
                    
                    case .synthesized(from: let base, for: let host):
                        // this is supported for backwards-compatibility, 
                        // but the `::SYNTHESIZED::` infix is deprecated, 
                        // so this will end up causing a redirect 
                        self.host = host
                        self.base = base 
                    }

                default: 
                    continue  
                }
            }
        }
    }
}

extension Link.Reference where Path.Element == Link.Component 
{
    var package:Package.ID? 
    {
        self.path.first?.identifier.map(Package.ID.init(_:))
    }
    var arrival:MaskedVersion? 
    {
        self.path.first?.version ?? nil
    }
    var module:Module.ID? 
    {
        guard case .identifier(let module, hyphen: nil)? = self.path.first
        else 
        {
            return nil
        }
        return .init(module)
    }
    
    var disambiguator:Link.Disambiguator 
    {
        .init(host: self.query.host, base: self.query.base, 
            suffix: self.path.last?.suffix ?? nil)
    }
}
