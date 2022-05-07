extension Symbol 
{
    fileprivate 
    struct DomesticPair:Hashable
    {
        private 
        let _witness:UInt32
        private 
        let _victim:UInt32
        
        var witness:Int 
        {
            .init(self._witness)
        }
        var victim:Int?
        {
            self._victim == .max ? nil : .init(self._victim)
        }
        
        init(_ index:Int) 
        {
            self._witness = .init(index)
            self._victim = .max
        }
        init(witness:Int, victim:Int)
        {
            self._witness = .init(witness)
            self._victim = .init(victim)
            precondition(self._victim != .max)
        }
    }
}
extension Package 
{
    struct Table 
    {
        var groups:[Symbol.Key: Symbol.Group] = [:]
        
        init() 
        {
            self.groups = [:]
        }
        
        func register(citizens:Symbol.IndexRange, among symbols:[Symbol], given ecosystem:Ecosystem)
        {
            
        }

        
        func resolve(module component:LexicalPath.Component) -> Int?
        {
            if case .identifier(let string, hyphen: nil) = component
            {
                return self.trunks[Module.ID.init(string)]
            }
            else 
            {
                return nil
            }
        }
        private 
        func depth(of symbol:(orientation:LexicalPath.Orientation, index:Int), in key:Key) -> Symbol.Depth?
        {
            self.groups[key]?.depth(of: symbol)
        }
        
        subscript(module module:Int, symbol path:LocalSelector) -> Symbol.Group?
        {
            self.groups     [Key.init(module: module, stem: path.stem, leaf: path.leaf)]
        }
        subscript(module module:Int, article leaf:UInt32) -> Int?
        {
            self.articles   [Key.init(module: module,                  leaf:      leaf)]
        }
        subscript(path:NationalSelector) -> NationalResolution?
        {
            switch path 
            {
            case .opaque(let opaque):
                // no additional lookups necessary
                return .opaque(opaque)
            
            case .symbol(module: let module, nil): 
                // no additional lookups necessary
                return .module(module)

            case .symbol(module: let module, let path?): 
                return self[module: module, symbol: path].map { NationalResolution.group($0, path.suffix) }
            
            case .article(module: let module, let leaf): 
                return self[module: module, article: leaf].map( NationalResolution.article(_:) )
            }
        }
    }
}
