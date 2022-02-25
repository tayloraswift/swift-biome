extension Biome 
{
    public 
    enum Module
    {
        public
        enum ID:Hashable, Comparable, Sendable
        {
            case swift 
            case concurrency
            case community(String)
            
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
    }
    public 
    struct _Module:Sendable 
    {
        typealias ID = Module.ID
        
        let id:ID
        let package:String?
        let symbols:[Range<Int>]
        var toplevel:[Int]
        
        init(id:ID, package:String?, symbols:[Range<Int>])
        {
            self.id = id 
            self.package = package
            self.symbols = symbols
            self.toplevel = []
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
    
    /* public 
    struct _Module 
    {
        let id:Module 
        let scope:[Module: [Int]]
        let symbols:[Module: Range<Int>]
        let title:String 
        let declaration:[Language.Lexeme]
    } */
}
