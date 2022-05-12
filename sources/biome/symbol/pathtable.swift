struct PathTable 
{
    private 
    var counter:Symbol.Key.Component
    private
    var table:[String: Symbol.Key.Component]
    
    init() 
    {
        self.counter = .init(bitPattern: 0)
        self.table = [:]
    }
    
    private static 
    func subpath<S>(_ component:S) -> String 
        where S:StringProtocol 
    {
        component.lowercased()
    }
    private static 
    func subpath<S>(_ components:S) -> String 
        where S:Sequence, S.Element:StringProtocol 
    {
        components.map { $0.lowercased() }.joined(separator: "\u{0}")
    }
    
    private 
    subscript(subpath:String) -> Symbol.Key.Component? 
    {
        self.table[subpath]
    }
    
    private 
    subscript<S>(leaf component:S) -> Symbol.Key.Component? 
        where S:StringProtocol 
    {
        self.table[Self.subpath(component)]
    }
    // this ignores the hyphen!
    subscript(leaf component:LexicalPath.Component) -> Symbol.Key.Component? 
    {
        guard case .identifier(let component, hyphen: _) = component
        else 
        {
            return nil
        }
        return self.table[Self.subpath(component)]
    }
    
    private 
    subscript<Path>(stem components:Path) -> Symbol.Key.Component? 
        where Path:Sequence, Path.Element:StringProtocol 
    {
        self.table[Self.subpath(components)]
    }
    private 
    subscript<Path>(stem components:Path) -> Symbol.Key.Component? 
        where Path:Sequence, Path.Element == LexicalPath.Component 
    {
        // all remaining components must be identifier-components, and only 
        // the last component may contain a hyphen.
        var stem:[String] = []
            stem.reserveCapacity(components.underestimatedCount)
        for component:LexicalPath.Component in components 
        {
            guard case .identifier(let component, hyphen: _) = component 
            else 
            {
                return nil 
            }
            stem.append(component)
        }
        return self.table[Self.subpath(stem)]
    }
    /* subscript<Path>(stem stem:Path, last:LexicalPath.Component) -> LocalSelector?
        where Path:Sequence, Path.Element == LexicalPath.Component
    {
        if case let (leaf, suffix)? = last.leaf, 
                let leaf:UInt32 = self[leaf: leaf], 
                let stem:UInt32 = self[stem: stem]
        {
            return .init(stem: stem, leaf: leaf, suffix: suffix)
        }
        else 
        {
            return nil 
        }
    } */
    
    private mutating 
    func register(_ string:String) -> Symbol.Key.Component 
    {
        var counter:Symbol.Key.Component = self.counter.successor
        self.table.merge(CollectionOfOne<(String, Symbol.Key.Component)>.init((string, counter))) 
        { 
            (current:Symbol.Key.Component, _:Symbol.Key.Component) in 
            counter = current 
            return current 
        }
        return counter
    }
    mutating 
    func register<S>(leaf component:S) -> Symbol.Key.Component 
        where S:StringProtocol 
    {
        self.register(Self.subpath(component))
    }
    mutating 
    func register<S>(stem components:S) -> Symbol.Key.Component 
        where S:Sequence, S.Element:StringProtocol 
    {
        self.register(Self.subpath(components))
    }
}
