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

struct SymbolTopics 
{
    enum Notes 
    {
        case feature(protocol:Organizer.Item<Organizer.Unconditional>)
        case member(overridden:[Organizer.Item<Organizer.Unconditional>])
        case requirement(restated:[Organizer.Item<Organizer.Unconditional>])

        func sorted() -> Self 
        {
            switch self 
            {
            case .feature(protocol: let coyote): 
                return .feature(protocol: coyote)
            case .member(overridden: let overridden): 
                return .member(overridden: overridden.sorted())
            case .requirement(restated: let restated): 
                return .requirement(restated: restated.sorted())
            }
        }
    }

    let notes:Notes? 
    // let articles:[Organizer.Card<String>]

    let requirements:[(Community, [Organizer.Card<Notebook<Highlight, Never>>])]

    let members:[(Community, [Organizer.Enclave<Organizer.Card<Notebook<Highlight, Never>>>])]
    let removed:[(Community, [Organizer.Enclave<Organizer.Card<Notebook<Highlight, Never>>>])]

    let implications:[Organizer.Item<Organizer.Unconditional>]

    let conformers:[Organizer.Enclave<Organizer.Item<Organizer.Conditional>>]
    let conformances:[Organizer.Enclave<Organizer.Item<Organizer.Conditional>>]

    let subclasses:[Organizer.Enclave<Organizer.Item<Organizer.Unconditional>>]
    let refinements:[Organizer.Enclave<Organizer.Item<Organizer.Unconditional>>]
    let implementations:[Organizer.Enclave<Organizer.Item<Organizer.Unconditional>>]
    let restatements:[Organizer.Enclave<Organizer.Item<Organizer.Unconditional>>]
    let overrides:[Organizer.Enclave<Organizer.Item<Organizer.Unconditional>>]

    init(notes:Notes?) 
    {
        //self.articles = []
        self.notes = notes?.sorted()

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
    private 
    init(_ organizer:Organizer, notes:Notes?)
    {
        //self.articles = organizer.articles.sorted()
        self.notes = notes?.sorted()
        
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

extension SymbolTopics 
{
    // takes an anisotropic context
    init(for atomic:Atom<Symbol>, 
        base:__shared SymbolReference,
        context:__shared AnisotropicContext,
        cache:inout ReferenceCache) throws
    {
        guard let metadata:Symbol.Metadata = context.local.metadata(local: atomic)
        else 
        {
            throw _MetadataLoadingError.init()
        }

        var organizer:Organizer = .init()
        try organizer.organize(metadata.primary, of: base, 
            diacritic: .init(atomic: atomic),
            culture: .primary,
            context: context,
            cache: &cache)
        
        for (culture, accepted):(Atom<Module>, Branch.SymbolTraits) in metadata.accepted 
        {
            try organizer.organize(accepted, of: base, 
                diacritic: .init(host: atomic, culture: culture), 
                culture: .accepted(try cache.load(culture, context: context)),
                context: context,
                cache: &cache)
        }
        for (consumer, versions):(Package.Index, [Version: Set<Atom<Module>>]) in 
            context.local.revision.consumers
        {
            guard   let pinned:Package.Pinned = context[consumer], 
                    let consumers:Set<Atom<Module>> = versions[pinned.version]
            else 
            {
                continue 
            }
            for culture:Atom<Module> in consumers 
            {
                assert(culture.nationality == consumer)

                let diacritic:Diacritic = .init(host: atomic, culture: culture)
                if let extra:Symbol.ForeignMetadata = pinned.metadata(foreign: diacritic)
                {
                    try organizer.organize(extra.traits, of: base, 
                        diacritic: diacritic, 
                        culture: .nonaccepted(
                            try cache.load(culture, context: context), 
                            try cache.load(consumer, context: context)),
                        context: context,
                        cache: &cache)
                }
            }
        }
        let notes:Notes? 
        if let roles:Branch.SymbolRoles = metadata.roles 
        {
            switch (base.community, base.shape) 
            {
            case (.protocol, _):
                try organizer.organize(roles, context: context, cache: &cache)
                notes = nil
            
            case (.callable,    .member?): 
                notes = .member(overridden: try roles.map 
                { 
                    try .init($0, context: context, cache: &cache) 
                })
            case (_,            .member?): 
                notes = nil
            case (_,            .requirement?):
                notes = .requirement(restated: try roles.map 
                { 
                    try .init($0, context: context, cache: &cache) 
                })
            case (_,            nil): 
                notes = nil 
            }
        }
        else 
        {
            notes = nil 
        }

        self.init(_move organizer, notes: _move notes)
    }
}


extension SymbolTopics  
{
    func html(context:some PackageContext, cache:inout ReferenceCache) 
        throws -> HTML.Element<Never>?
    {
        var sections:[HTML.Element<Never>] = []
        
        // topics.feed.isEmpty ? [] : 
        // [
        //     .section(self.render(cards: topics.feed), attributes: [.class("feed")])
        // ]

        if  let section:HTML.Element<Never> = self.refinements.section(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.implementations.section(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.restatements.section(
                heading: .h2("Refinements"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.overrides.section(
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
        
        if  let section:HTML.Element<Never> = self.conformers.section(
                heading: .h2("Conforming Types"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.conformances.section(
                heading: .h2("Conforms To"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if  let section:HTML.Element<Never> = self.subclasses.section(
                heading: .h2("Subclasses"), 
                attributes: [.class("related")])
        {
            sections.append(section)
        }
        if !self.implications.isEmpty
        {
            sections.append(.section(.h2("Implies"), .ul(self.implications.flatMap(\.html)), 
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


extension Collection where Element:HTMLConvertible
{
    fileprivate 
    func section(heading:HTML.Element<Never>, attributes:[HTML.Element<Never>.Attribute] = [])
        -> HTML.Element<Never>?
    {
        self.isEmpty ? nil : 
            .section([heading] + self.lazy.map(\.html).joined(), attributes: attributes)
    }
}
extension Sequence<Organizer.Enclave<Organizer.Card<Notebook<Highlight, Never>>>>
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
