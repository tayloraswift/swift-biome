import HTML

extension _Topics 
{
    struct Item<Constraints> 
    {
        // the path and uri do not necessarily originate from the same symbol
        let constraints:Constraints
        let display:Path 
        let uri:String 

        private 
        init(where constraints:Constraints,
            display:Path,
            uri:String)
        {
            self.constraints = constraints
            self.display = display
            self.uri = uri
        }
    }
}
extension _Topics.Item
{
    private 
    init(_ symbol:SymbolReference, 
        where constraints:Constraints, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        let display:Path 
        switch symbol.community 
        {
        case .associatedtype, .callable(_):
            guard let scope:PluralPosition<Symbol> = symbol.shape?.target 
            else 
            {
                fallthrough
            }
            display = cache.load(scope, context: context).path
        default: 
            display = symbol.path
        }
        self.init(where: constraints, display: display, uri: symbol.uri)
    }
}
extension _Topics.Item<Void>
{
    init(_ symbol:SymbolReference, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        try self.init(symbol, where: (), context: context, cache: &cache)
    }
    init(_ symbol:Atom<Symbol>, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        try self.init(try cache.load(symbol, context: context), where: (), 
            context: context, 
            cache: &cache)
    }
}
extension _Topics.Item<[Generic.Constraint<String>]>
{
    init(_ symbol:Atom<Symbol>, 
        where constraints:[Generic.Constraint<Atom<Symbol>>], 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        try self.init(try cache.load(symbol, context: context), 
            where: try constraints.map 
            {
                try $0.map { try cache.load($0, context: context).uri }
            }, 
            context: context, 
            cache: &cache)
    }
}
extension Sequence 
{
    func sorted<T>() -> [_Topics.Item<T>] 
        where Element == _Topics.Item<T> 
    {
        self.sorted { $0.display |<| $1.display }
    }
}



extension _Topics.Item<Void>
{
    var html:HTML.Element<Never>
    {
        .li(.a(.code(self.display.html), 
            attributes: [.href(self.uri), .class("signature")]))
    }
}
extension _Topics.Item<[Generic.Constraint<String>]>
{
    var html:HTML.Element<Never>
    {
        let signature:HTML.Element<Never> = .a(.code(self.display.html), 
            attributes: [.href(self.uri), .class("signature")])
        if let constraints:[HTML.Element<Never>] = self.constraints.html
        {
            return .li(signature, .p([.init(escaped: "When ")] + constraints))
        }
        else 
        {
            return .li(signature)
        }
    }
}

extension Path 
{
    var html:[HTML.Element<Never>]
    {
        var components:[HTML.Element<Never>] = []
            components.reserveCapacity(2 * self.count - 1)
        for component:String in self.prefix
        {
            components.append(.highlight(component, .identifier))
            components.append(.highlight(escaped: ".", .text))
        }
        components.append(.highlight(self.last, .identifier))
        return components
    }
}

extension BidirectionalCollection<Generic.Constraint<String>> 
{
    var html:[HTML.Element<Never>]?
    {
        var reversed:ReversedCollection<Self.Indices>.Iterator = 
            self.indices.reversed().makeIterator()

        guard let ultimate:Index = reversed.next()
        else 
        {
            return nil
        }
        guard let penultimate:Index = reversed.next()
        else 
        {
            return self[ultimate].html
        }

        guard let partition:Index = reversed.next() 
        else 
        {
            return self[penultimate].html + [.init(escaped: " and ")] + self[ultimate].html 
        }

        var elements:[HTML.Element<Never>] = []
        for constraint:Generic.Constraint<String> in self.prefix(through: partition)
        {
            elements.append(contentsOf: constraint.html)
            elements.append(.init(escaped: ", "))
        }
        elements.append(contentsOf: self[penultimate].html)
        elements.append(.init(escaped: ", and "))
        elements.append(contentsOf: self[ultimate].html)
        
        return elements
    }
}
extension Generic.Constraint<String> 
{
    var html:[HTML.Element<Never>] 
    {
        let verb:String
        switch self.verb
        {
        case .subclasses: 
            verb = " inherits from "
        case .implements:
            verb = " conforms to "
        case .is:
            verb = " is "
        }
        let subject:HTML.Element<Never> = .code(.highlight(self.subject, .type))
        let object:HTML.Element<Never> = .code(.highlight(self.object, .type, uri: self.target))
        return [subject, .init(escaped: verb), object]
    }
}