struct Topics 
{
    enum Sublist:Hashable, Sendable
    {
        case color(Symbol.Color)
    }
    enum List:Hashable, Sendable 
    {
        case conformers
        case conformances
        case subclasses
        case implies
        case refinements
        case implementations
        case restatements 
        case overrides
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
