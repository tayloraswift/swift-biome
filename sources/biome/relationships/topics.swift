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
        case implies            = "Implies"
        case refinements        = "Refinements"
        case implementations    = "Implemented By"
        case restatements       = "Restated By"
        case overrides          = "Overridden By"
    }
    
    var requirements:[Sublist: [Module.Culture: [Symbol.Composite]]]
    var members:[Sublist: [Module.Culture: [Symbol.Composite]]]
    var lists:[List: [Module.Culture: [Symbol.Conditional]]]
    
    init() 
    {
        self.requirements = [:]
        self.members = [:]
        self.lists = [:]
    }
}
