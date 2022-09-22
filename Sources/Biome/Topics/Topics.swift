import DOM
import HTML
import Notebook 

infix operator |<| :ComparisonPrecedence 

/// Orders two paths first by final component, and then by scope.
func |<| (
    lhs:(prefix:some Sequence<String>, last:String), 
    rhs:(prefix:some Sequence<String>, last:String)) -> Bool 
{
    if      lhs.last <  rhs.last 
    {
        return true 
    }
    else if lhs.last == rhs.last 
    {
        return lhs.prefix.lexicographicallyPrecedes(rhs.prefix)
    }
    else 
    {
        return false 
    }
}

extension Path 
{
    static 
    func |<| (lhs:Self, rhs:Self) -> Bool 
    {
        (lhs.prefix, lhs.last) |<| (rhs.prefix, rhs.last)
    }
}

struct _Topics 
{
    let articles:[Card<String>]

    let requirements:[(Community, [Card<Notebook<Highlight, Never>>])]

    let members:[(Community, [Enclave<Card<Notebook<Highlight, Never>>>])]
    let removed:[(Community, [Enclave<Card<Notebook<Highlight, Never>>>])]

    let implications:[Item<Void>]

    let conformers:[Enclave<Item<[Generic.Constraint<String>]>>]
    let conformances:[Enclave<Item<[Generic.Constraint<String>]>>]

    let subclasses:[Enclave<Item<Void>>]
    let refinements:[Enclave<Item<Void>>]
    let implementations:[Enclave<Item<Void>>]
    let restatements:[Enclave<Item<Void>>]
    let overrides:[Enclave<Item<Void>>]

    init() 
    {
        self.articles = []

        self.requirements = []

        self.members = []
        self.removed = []

        self.implications = []

        self.conformers = []
        self.conformances = []

        self.subclasses = []
        self.refinements = []
        self.implementations = []
        self.restatements = []
        self.overrides = []
    }
    init(_ organizer:Organizer)
    {
        self.articles = organizer.articles.sorted()

        self.requirements = organizer.requirements.sublists { $0.sorted() }

        self.members = organizer.members.sublists { $0.values.sorted().map { $0.sorted() } }
        self.removed = organizer.removed.sublists { $0.values.sorted().map { $0.sorted() } }

        self.implications = organizer.implications.sorted()

        self.conformers         =      organizer.conformers.values.sorted().map { $0.sorted() }
        self.conformances       =    organizer.conformances.values.sorted().map { $0.sorted() }

        self.subclasses         =      organizer.subclasses.values.sorted().map { $0.sorted() }
        self.refinements        =     organizer.refinements.values.sorted().map { $0.sorted() }
        self.implementations    = organizer.implementations.values.sorted().map { $0.sorted() }
        self.restatements       =    organizer.restatements.values.sorted().map { $0.sorted() }
        self.overrides          =       organizer.overrides.values.sorted().map { $0.sorted() }
    }
}
extension Dictionary where Key:CaseIterable 
{
    fileprivate
    func sublists<Sublist>(_ transform:(Value) throws -> Sublist) rethrows -> [(Key, Sublist)]
    {
        try Key.allCases.compactMap
        {
            (key:Key) in try self[key].map { (key, try transform($0)) }
        }
    }
}


extension _Topics 
{
    func html(context:Package.Context, cache:inout _ReferenceCache) throws -> HTML.Element<Never>?
    {
        var sections:[HTML.Element<Never>] = []
        
        // topics.feed.isEmpty ? [] : 
        // [
        //     .section(self.render(cards: topics.feed), attributes: [.class("feed")])
        // ]

        if  let section:HTML.Element<Never> = self.refinements.list(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.implementations.list(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.restatements.list(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.overrides.list(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        
        if !self.requirements.isEmpty
        {
            sections.append(.section(try [.h2("Requirements")] + self.requirements.map 
                {
                    .section(.h3($0.0.plural), .ul(try $0.1.map 
                    {
                        try $0.html(context: context, cache: &cache)
                    }))
                },
                attributes: [.class("topics requirements")]))
        }
        if !self.members.isEmpty
        {
            sections.append(.section(try [.h2("Members")] + self.members.map 
                {
                    try $0.1.grid(heading: .h3($0.0.plural))
                    {
                        try $0.html(context: context, cache: &cache)
                    }
                },
                attributes: [.class("topics members")]))
        }
        
        if  let section:HTML.Element<Never> = self.conformers.list(
                heading: .h2("Conforming Types"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.conformances.list(
                heading: .h2("Conforms To"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.subclasses.list(
                heading: .h2("Subclasses"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if !self.implications.isEmpty
        {
            sections.append(.section(.h2("Implies"), .ul(self.implications.map(\.html)), 
                attributes: [.class("related")]))
        }

        if !self.removed.isEmpty
        {
            sections.append(.section(try [.h2("Removed Members")] + self.removed.map 
                {
                    try $0.1.grid(heading: .h3($0.0.plural))
                    {
                        try $0.html(context: context, cache: &cache)
                    }
                },
                attributes: [.class("topics removed")]))
        }
        
        return sections.isEmpty ? nil : .div(sections)
    }
}


extension Collection<_Topics.Enclave<_Topics.Item<Void>>>
{
    fileprivate 
    func list(heading:HTML.Element<Never>, attributes:[HTML.Element<Never>.Attribute] = [])
        -> HTML.Element<Never>?
    {
        self.isEmpty ? nil : 
            .section([heading] + self.lazy.map(\.html).joined(), attributes: attributes)
    }
}
extension Collection<_Topics.Enclave<_Topics.Item<[Generic.Constraint<String>]>>>
{
    fileprivate 
    func list(heading:HTML.Element<Never>, attributes:[HTML.Element<Never>.Attribute] = [])
        -> HTML.Element<Never>?
    {
        self.isEmpty ? nil : 
            .section([heading] + self.lazy.map(\.html).joined(), attributes: attributes)
    }
}
extension Sequence<_Topics.Enclave<_Topics.Card<Notebook<Highlight, Never>>>>
{
    fileprivate 
    func grid(heading:HTML.Element<Never>, html:(Element) throws -> [HTML.Element<Never>]) 
        rethrows -> HTML.Element<Never>
    {
        var enclaves:Iterator = self.makeIterator() 
        guard let first:[HTML.Element<Never>] = try enclaves.next().map(html)
        else 
        {
            return .section(heading) 
        }
        // CSS grid will be unhappy if the first enclave has more than 1 dom element 
        var elements:[HTML.Element<Never>] = []
        if  first.count > 1 
        {
            elements.reserveCapacity(2 * self.underestimatedCount + 2)
            elements.append(heading)
            elements.append(.ul())
        }
        else 
        {
            elements.reserveCapacity(2 * self.underestimatedCount)
            elements.append(heading)
        }

        elements.append(contentsOf: _move first)

        while let next:[HTML.Element<Never>] = try enclaves.next().map(html)
        {
            elements.append(contentsOf: next)
        }
        
        return .section(elements) 
    }
}
