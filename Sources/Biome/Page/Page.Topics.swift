import SymbolGraphs

extension Page 
{
    enum Card 
    {
        case composite(Composite, Declaration<Symbol.Index>)
        case article(Article.Index, Article.Metadata)
    }
    
    enum Sublist:Hashable, CaseIterable, Sendable
    {
        case community(Community)
        
        var heading:String 
        {
            switch self 
            {
            case .community(let community): return community.plural
            }
        }
        
        static 
        let allCases:[Self] = Community.allCases.map(Self.community(_:))
    }
    enum List:String, Hashable, Sendable 
    {
        case conformers         = "Conforming Types"
        case conformances       = "Conforms To"
        case subclasses         = "Subclasses"
        case implications       = "Implies"
        case refinements        = "Refinements"
        case implementations    = "Implemented By"
        case restatements       = "Restated By"
        case overrides          = "Overridden By"
    }
    struct Topics 
    {
        enum Key:Hashable, Sendable 
        {
            case composite(Composite)
            case article(Article.Index)
            case href(Ecosystem.Index)
        }
        
        var feed:[Card]
        var requirements:[Sublist: [Card]]
        var members:[Sublist: [Module._Culture: [Card]]]
        var removed:[Sublist: [Module._Culture: [Card]]]
        var lists:[List: [Module._Culture: [Generic.Conditional<Symbol.Index>]]]
        
        var isEmpty:Bool 
        {
            self.feed.isEmpty &&
            self.requirements.isEmpty && 
            self.members.isEmpty && 
            self.removed.isEmpty && 
            self.lists.isEmpty 
        }
        
        init() 
        {
            self.feed = []
            self.requirements = [:]
            self.members = [:]
            self.removed = [:]
            self.lists = [:]
        }
        
        mutating 
        func sort(by ecosystem:Ecosystem)
        {
            self.feed.sort(by: ecosystem)
            self.requirements.sortValues(by: ecosystem)
            for index:Dictionary<Sublist, [Module._Culture: [Card]]>.Index in self.members.indices 
            {
                self.members.values[index].sortValues(by: ecosystem)
            }
            for index:Dictionary<Sublist, [Module._Culture: [Card]]>.Index in self.removed.indices 
            {
                self.removed.values[index].sortValues(by: ecosystem)
            }
            for index:Dictionary<List, [Module._Culture: [Generic.Conditional<Symbol.Index>]]>.Index in 
                self.lists.indices 
            {
                self.lists.values[index].sortValues(by: ecosystem)
            }
        }
    }
}

extension Page
{
    func organize(toplevel:Set<Symbol.Index>, guides:Set<Article.Index>) -> Topics 
    {
        var topics:Topics = .init()
        for article:Article.Index in guides
        {
            if  let metadata:Article.Metadata = 
                    self.pin(article.nationality).metadata(local: article)
            {
                topics.feed.append(.article(article, metadata))
            }
        }
        for symbol:Symbol.Index in toplevel
        {
            // all toplevel symbols are natural and of the module’s primary culture
            self.add(member: .init(natural: symbol), culture: .primary, to: &topics)
        }
        
        topics.sort(by: self.ecosystem)
        return topics
    }

    private 
    func add(member composite:Composite, culture:Module._Culture, to topics:inout Topics)
    {
        let sublist:Sublist = .community(self.ecosystem[composite.base].community)
        let declaration:Declaration<Symbol.Index> = 
            self.pin(composite.base.nationality).declaration(for: composite.base)!
        // every sublist has a sub-sublist for the primary culture, even if it 
        // is empty. this is more css-grid friendly.
        var empty:[Module._Culture: [Card]] { [.primary: []] }
        if  declaration.availability.isUsable 
        {
            topics.members[sublist, default: empty][culture, default: []]
                .append(.composite(composite, declaration))
        }
        else 
        {
            topics.removed[sublist, default: empty][culture, default: []]
                .append(.composite(composite, declaration))
        }
    }
}

extension MutableCollection 
    where Self:RandomAccessCollection, Element == Generic.Conditional<Symbol.Index>
{
    fileprivate mutating 
    func sort(by ecosystem:Ecosystem) 
    {
        self.sort
        {
            ecosystem[$0.target].path.lexicographicallyPrecedes(ecosystem[$1.target].path)
        }
    }
}
extension MutableCollection 
    where Self:RandomAccessCollection, Element == Page.Card
{
    fileprivate mutating 
    func sort(by ecosystem:Ecosystem) 
    {
        self.sort 
        {
            // this lexicographic ordering sorts by last path component first, 
            // and *then* by vending protocol (if applicable)
            let path:(Path, Path) 
            switch ($0, $1)
            {
            case (.article(_, _), .composite(_, _)):
                return true 
            case (.article(let first, _), .article(let second, _)):
                path = (ecosystem[first].path, ecosystem[second].path)
            case (.composite(let first, _), .composite(let second, _)):
                path = (ecosystem[first.base].path, ecosystem[second.base].path)
            case (.composite(_, _), .article(_, _)):
                return false
            }
            if  path.0.last < path.1.last 
            {
                return true 
            }
            else if path.0.last == path.1.last 
            {
                return path.0.prefix.lexicographicallyPrecedes(path.1.prefix)
            }
            else 
            {
                return false 
            }
        }
    }
}
extension Dictionary 
    where   Value:MutableCollection & RandomAccessCollection, 
            Value.Element == Generic.Conditional<Symbol.Index>
{
    fileprivate mutating 
    func sortValues(by ecosystem:Ecosystem)
    {
        for index:Index in self.indices 
        {
            self.values[index].sort(by: ecosystem)
        }
    }
}
extension Dictionary 
    where   Value:MutableCollection & RandomAccessCollection, 
            Value.Element == Page.Card 
{
    fileprivate mutating 
    func sortValues(by ecosystem:Ecosystem)
    {
        for index:Index in self.indices 
        {
            self.values[index].sort(by: ecosystem)
        }
    }
}
