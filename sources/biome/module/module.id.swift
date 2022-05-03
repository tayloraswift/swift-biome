extension Module 
{
    public
    struct ID:Hashable, Sendable, Decodable, ExpressibleByStringLiteral, CustomStringConvertible
    {
        public
        let string:String 
        
        public 
        var description:String 
        {
            self.string 
        }
        
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
        
        @inlinable public 
        init(from decoder:any Decoder) throws 
        {
            self.init(try decoder.decode(String.self))
        }
        public
        init(stringLiteral:String)
        {
            self.string = stringLiteral
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
}
