extension Biome 
{    
    public 
    struct Module:Identifiable, Sendable
    {
        @frozen public
        struct ID:Hashable, Sendable, ExpressibleByStringLiteral
        {
            public
            let string:String 
            
            var trunk:[UInt8]
            {
                Documentation.URI.encode(component: self.title.utf8)
            }
            
            @inlinable public
            init(stringLiteral:String)
            {
                self.string = stringLiteral
            }
            init<S>(_ string:S) where S:StringProtocol 
            {
                self.string = .init(string)
            }
            var title:Substring 
            {
                self.string.drop { $0 == "_" } 
            }
            func graphIdentifier(bystander:Self?) -> String
            {
                bystander.map { "\(self.string)@\($0.string).symbols.json" } ?? "\(self.string).symbols.json"
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
}
