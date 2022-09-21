import DOM
import Notebook 

struct _Topics 
{
    struct ArticleCard 
    {
        let element:Atom<Article>
        let overview:DOM.Flattened<GlobalLink.Presentation>
    }
    struct SymbolCard
    {
        let composite:Composite 
        let signature:Notebook<Highlight, Never>
        let overview:DOM.Flattened<GlobalLink.Presentation>

        init(composite:Composite, 
            signature:Notebook<Highlight, Never>, 
            overview:DOM.Flattened<GlobalLink.Presentation>)
        {
            self.composite = composite
            self.signature = signature
            self.overview = overview
        }
        init(composite:Composite, 
            signature:Notebook<Highlight, Never>?, 
            overview:DOM.Flattened<GlobalLink.Presentation>?)
        {
            self.composite = composite
            self.signature = signature ?? 
                .init(CollectionOfOne<(String, Highlight)>.init(("<unavailable>", .text)))
            self.overview = overview ?? .init()
        }
    }
    enum Culture:Hashable, Comparable
    {
        case primary 
        case accepted(Module.ID)
        case nonaccepted(Module.ID)
    }
    struct Enclave<Item>:Identifiable
    {
        let id:Culture 
        var items:[Item]

        init(id:Culture, items:[Item] = [])
        {
            self.id = id 
            self.items = items 
        }
    }

    let articles:[ArticleCard]

    let requirements:[(Community, [SymbolCard])]

    let members:[(Community, [Enclave<SymbolCard>])]
    let removed:[(Community, [Enclave<SymbolCard>])]

    let implications:[Atom<Symbol>]

    let conformers:[Enclave<Generic.Conditional<Atom<Symbol>>>]
    let conformances:[Enclave<Generic.Conditional<Atom<Symbol>>>]

    let subclasses:[Enclave<Atom<Symbol>>]
    let refinements:[Enclave<Atom<Symbol>>]
    let implementations:[Enclave<Atom<Symbol>>]
    let restatements:[Enclave<Atom<Symbol>>]
    let overrides:[Enclave<Atom<Symbol>>]

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
        self.articles = organizer.articles

        self.requirements = organizer.requirements.sublists { $0 }

        self.members = organizer.members.sublists { $0.values.sorted() }
        self.removed = organizer.removed.sublists { $0.values.sorted() }

        self.implications = organizer.implications 

        self.conformers = organizer.conformers.values.sorted()
        self.conformances = organizer.conformances.values.sorted()

        self.subclasses = organizer.subclasses.values.sorted()
        self.refinements = organizer.refinements.values.sorted()
        self.implementations = organizer.implementations.values.sorted()
        self.restatements = organizer.restatements.values.sorted()
        self.overrides = organizer.overrides.values.sorted()
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
extension Sequence 
{
    fileprivate
    func sorted<Item>() -> [Element] where Element == _Topics.Enclave<Item> 
    {
        self.sorted { $0.id < $1.id }
    }
}