extension Biome.Module 
{
    @frozen public
    struct ID:Hashable, Sendable, ExpressibleByStringLiteral
    {
        public
        let string:String 
        
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
}
