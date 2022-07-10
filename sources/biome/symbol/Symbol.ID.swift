extension Symbol 
{
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }
    
    @usableFromInline 
    struct ID:Hashable, CustomStringConvertible, Sendable 
    {
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
        
        @usableFromInline 
        var description:String
        {
            self.string
        }
    }
}
