struct Topics 
{
    enum Sublist:Hashable, CaseIterable, Sendable
    {
        case color(Symbol.Color)
        
        var heading:String 
        {
            switch self 
            {
            case .color(let color): return color.plural
            }
        }
        
        static 
        let allCases:[Self] = Symbol.Color.allCases.map(Self.color(_:))
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
    
    var requirements:[Sublist: [Symbol.Card]]
    var members:[Sublist: [Module.Culture: [Symbol.Card]]]
    var removed:[Sublist: [Module.Culture: [Symbol.Card]]]
    var lists:[List: [Module.Culture: [Symbol.Conditional]]]
    
    var isEmpty:Bool 
    {
        self.requirements.isEmpty && 
        self.members.isEmpty && 
        self.removed.isEmpty && 
        self.lists.isEmpty 
    }
    
    init() 
    {
        self.requirements = [:]
        self.members = [:]
        self.removed = [:]
        self.lists = [:]
    }
}
