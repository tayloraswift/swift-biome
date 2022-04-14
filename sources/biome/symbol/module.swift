public 
struct Module:Identifiable, Sendable
{
    public
    struct ID:Hashable, Sendable, ExpressibleByStringLiteral
    {
        public
        let string:String 
        // lowercased. it is possible for lhs == rhs even if lhs.string != rhs.string
        var value:String 
        {
            self.title.lowercased()
        }
        
        public static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.value == rhs.value
        }
        public 
        func hash(into hasher:inout Hasher) 
        {
            self.value.hash(into: &hasher)
        }
        
        @available(*, deprecated, renamed: "value")
        var trunk:[UInt8]
        {
            Documentation.URI.encode(component: self.title.utf8)
        }
        
        public
        init(stringLiteral:String)
        {
            self.init(stringLiteral)
        }
        @inlinable public
        init<S>(_ string:S) where S:StringProtocol 
        {
            self.string = .init(string)
        }
        var title:Substring 
        {
            self.string.drop { $0 == "_" } 
        }
    }
    
    public 
    let id:ID
    let package:Int
    
    let symbols:(core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
    var toplevel:[Int]
    
    var title:String 
    {
        .init(self.id.title)
    }
    var allSymbols:FlattenSequence<[Range<Int>]>
    {
        ([self.symbols.core] + self.symbols.extensions.map(\.symbols)).joined()
    }
    
    init(id:ID, package:Int, core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
    {
        self.id         = id 
        self.package    = package
        self.symbols    = (core, extensions)
        self.toplevel   = []
    }
}
