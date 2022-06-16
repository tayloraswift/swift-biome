struct Topics 
{
    enum Sublist:Hashable, Sendable
    {
        case color(Symbol.Color)
    }
    enum List:String, Hashable, Sendable 
    {
        case conformers         = "Conforming Types"
        case conformances       = "Conforms To"
        case subclasses         = "Subclasses"
        case implies            = "Implies"
        case refinements        = "Refinements"
        case implementations    = "Default Implementations"
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
