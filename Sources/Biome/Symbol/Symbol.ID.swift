extension Symbol 
{
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }
    
    @frozen public
    struct ID:Hashable, CustomStringConvertible, Sendable 
    {
        public 
        let string:String 
        
        init(string:String)
        {
            self.string = string
        }
        init<ASCII>(_ language:Language, _ mangled:ASCII) where ASCII:Collection, ASCII.Element == UInt8 
        {
            self.string = "\(language.rawValue)\(String.init(decoding: mangled, as: Unicode.ASCII.self))"
        }
        
        var language:Language 
        {
            guard let language:Language = self.string.unicodeScalars.first.flatMap(Language.init(rawValue:))
            else 
            {
                // should always be round-trippable
                fatalError("unreachable")
            }
            return language 
        }
        
        @inlinable public
        var description:String
        {
            self.string
        }
    }
}
