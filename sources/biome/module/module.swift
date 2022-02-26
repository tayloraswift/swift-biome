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
        struct View:RandomAccessCollection, Sendable
        {
            public 
            typealias Index = Module.Index
            /* public 
            typealias Indices = Range<Module.Index>
            public 
            typealias SubSequence = ArraySlice<Module> */
            
            private 
            var modules:[Module]
            private 
            let lookup:[ID: Index]
            
            public 
            var startIndex:Index 
            {
                .init(self.modules.startIndex)
            }
            public 
            var endIndex:Index 
            {
                .init(self.modules.endIndex)
            }
            /* public 
            var indices:Range<Index> 
            {
                self.startIndex ..< self.endIndex
            } */
            
            public 
            subscript(index:Index) -> Module 
            {
                _read 
                {
                    yield self.modules[index.value]
                }
                _modify
                {
                    yield &self.modules[index.value]
                }
            }
            /* public 
            subscript(range:Range<Index>) -> ArraySlice<Module> 
            {
                _read 
                {
                    yield self.modules[range.lowerBound.value ..< range.upperBound.value]
                }
                _modify
                {
                    yield &self.modules[range.lowerBound.value ..< range.upperBound.value]
                }
            } */
            
            init(_ modules:[Module], indices:[ID: Index])
            {
                self.modules = modules 
                self.lookup = indices 
            }
            
            func index(of id:ID) throws -> Index
            {
                guard let index:Index = self.lookup[id]
                else 
                {
                    throw ModuleIdentifierError.undefined(module: id)
                }
                return index
            }
        }
        public 
        struct Index:Hashable, Comparable, Strideable, Sendable 
        {
            public 
            typealias Stride = Int 
            
            let value:Int 
            
            public static 
            func < (lhs:Self, rhs:Self) -> Bool 
            {
                lhs.value < rhs.value
            }
            
            init(_ value:Int)
            {
                self.value = value
            }
            
            public 
            func advanced(by distance:Int) -> Self 
            {
                .init(self.value + distance)
            }
            public 
            func distance(to index:Self) -> Int
            {
                index.value - self.value
            }
        }
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
        
        let symbols:(core:Range<Int>, extensions:[(bystander:Index, symbols:Range<Int>)])
        var toplevel:[Int]
        
        var topics:[(heading:Biome.Topic, indices:[Int])]
        var declaration:[Language.Lexeme] 
        {
            [.code("import", class: .keyword(.other)), .spaces(1), .code(self.id.identifier, class: .identifier)]
        }
        var title:String 
        {
            self.id.title
        }
        
        init(id:ID, package:String?, path:Path, core:Range<Int>, 
            extensions:[(bystander:Index, symbols:Range<Int>)])
        {
            self.id         = id 
            self.package    = package
            self.path       = path
            self.symbols    = (core, extensions)
            self.toplevel   = []
            self.topics     = []
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
