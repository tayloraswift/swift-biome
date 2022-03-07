extension Biome 
{    
    public 
    struct Module:Identifiable, Sendable
    {
        public
        enum ID:Hashable, Comparable, Sendable
        {
            case swift 
            case dispatch
            case concurrency
            case differentiation
            case distributed
            case matchingEngine
            case stringProcessing
            case community(String)
            
            init<S>(_ string:S) where S:StringProtocol 
            {
                switch string 
                {
                case "Swift":               self = .swift 
                case "Dispatch":            self = .dispatch 
                case "_Concurrency":        self = .concurrency
                case "_Differentiation":    self = .differentiation
                case "_Distributed":        self = .distributed
                case "_MatchingEngine":     self = .matchingEngine
                case "_StringProcessing":   self = .stringProcessing
                default:                    self = .community(String.init(string))
                }
            }
            
            var identifier:String 
            {
                switch self 
                {
                case .swift:            return "Swift"
                case .dispatch:         return "Dispatch"
                case .concurrency:      return "_Concurrency"
                case .differentiation:  return "_Differentiation"
                case .distributed:      return "_Distributed"
                case .matchingEngine:   return "_MatchingEngine"
                case .stringProcessing: return "_StringProcessing"
                case .community(let module):
                    return module
                }
            }
            var title:String 
            {
                switch self 
                {
                case .swift:            return "Swift"
                case .dispatch:         return "Dispatch"
                case .concurrency:      return "Concurrency"
                case .differentiation:  return "Differentiation"
                case .distributed:      return "Distributed"
                case .matchingEngine:   return "MatchingEngine"
                case .stringProcessing: return "StringProcessing"
                case .community(let module):
                    return module
                }
            }
            var declaration:[SwiftLanguage.Lexeme<Symbol.ID>]
            {
                [
                    .code("import", class: .keyword(.other)),
                    .spaces(1),
                    .code(self.identifier, class: .identifier)
                ]
            }
            func graphIdentifier(bystander:Self?) -> String
            {
                bystander.map { "\(self.identifier)@\($0.identifier)" } ?? self.identifier
            }
        }
        
        public 
        let id:ID
        public 
        let package:Int
        let path:Path
        
        let symbols:(core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
        var toplevel:[Int]
        
        var topics:
        (
            members:[(heading:Biome.Topic, indices:[Int])],
            removed:[(heading:Biome.Topic, indices:[Int])]
        )
        var title:String 
        {
            self.id.title
        }
        var allSymbols:FlattenSequence<[Range<Int>]>
        {
            ([self.symbols.core] + self.symbols.extensions.map(\.symbols)).joined()
        }
        
        init(id:ID, package:Int, path:Path, core:Range<Int>, 
            extensions:[(bystander:Int, symbols:Range<Int>)])
        {
            self.id         = id 
            self.package    = package
            self.path       = path
            self.symbols    = (core, extensions)
            self.toplevel   = []
            self.topics     = ([], [])
        }
    }
    
    public 
    struct Graph:Hashable, Sendable 
    {
        var module:Module.ID, 
            bystander:Module.ID?
        
        var namespace:Module.ID 
        {
            self.bystander ?? self.module 
        }
    }
}
