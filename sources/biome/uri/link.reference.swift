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
        init(path:Path, query:Query = .init(), orientation:Route.Orientation = .gay)
        {
            self.path = path 
            self.query = query 
            self.orientation = orientation
        }
        
        var nation:Package.ID? 
        {
            guard case .identifier(let package, hyphen: _)? = self.path.first
            else 
            {
                return nil
            }
            return .init(package)
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
        
        var disambiguation:Disambiguation 
        {
            .init(
                suffix: self.path.last?.suffix ?? nil,
                victim: self.query.victim,
                symbol: self.query.symbol)
        }
    }
    
    struct Query 
    {
        var victim:Symbol.ID?
        var symbol:Symbol.ID?
        var culture:Package.ID?
        
        init() 
        {
            self.victim = nil
            self.symbol = nil 
            self.culture = nil 
        }
        
        mutating 
        func update(normalizing parameters:[URI.Parameter]) throws 
        {
            for (key, value):(String, String) in parameters 
            {
                switch key
                {
                case "from":
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.culture = .init(value)
                
                case "self":
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.victim  = try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.OpaqueName.self)
                
                case "overload": 
                    switch         try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.self) 
                    {
                    case .natural(let symbol):
                        self.symbol = symbol
                    
                    case .synthesized(from: let symbol, for: let victim):
                        // this is supported for backwards-compatibility, 
                        // but the `::SYNTHESIZED::` infix is deprecated, 
                        // so this will end up causing a redirect 
                        self.victim = victim
                        self.symbol = symbol 
                    }

                default: 
                    continue  
                }
            }
        }
    }
}
