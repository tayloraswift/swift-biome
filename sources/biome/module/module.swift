extension Biome 
{
    public 
    enum ModuleIdentifierError:Error 
    {
        case mismatch(decoded:Module.ID, expected:Module.ID)
        case duplicate(module:Module.ID)
        case undefined(module:Module.ID)
    }
    
    public 
    struct Module:Identifiable, Sendable
    {
        public
        enum ID:Hashable, Comparable, Sendable
        {
            case swift 
            case concurrency
            case community(String)
            
            init<S>(_ string:S) where S:StringProtocol 
            {
                switch string 
                {
                case "Swift":           self = .swift 
                case "_Concurrency":    self = .concurrency
                default:                self = .community(String.init(string))
                }
            }
            
            var identifier:String 
            {
                switch self 
                {
                case .swift:
                    return "Swift"
                case .concurrency:
                    return "_Concurrency"
                case .community(let module):
                    return module
                }
            }
            var title:String 
            {
                switch self 
                {
                case .swift:
                    return "Swift"
                case .concurrency:
                    return "Concurrency"
                case .community(let module):
                    return module
                }
            }
            var declaration:[Language.Lexeme]
            {
                [
                    .code("import", class: .keyword(.other)),
                    .spaces(1),
                    .code(self.identifier, class: .identifier)
                ]
            }
        }
        
        public 
        let id:ID
        public 
        let package:String?
        let path:Path
        
        let symbols:(core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
        var toplevel:[Int]
        
        var topics:
        (
            members:[(heading:Biome.Topic, indices:[Int])],
            removed:[(heading:Biome.Topic, indices:[Int])]
        )
        var declaration:[Language.Lexeme] 
        {
            [.code("import", class: .keyword(.other)), .spaces(1), .code(self.id.identifier, class: .identifier)]
        }
        var title:String 
        {
            self.id.title
        }
        var allSymbols:[Range<Int>] 
        {
            [self.symbols.core] + self.symbols.extensions.map(\.symbols)
        }
        
        init(id:ID, package:String?, path:Path, core:Range<Int>, 
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
