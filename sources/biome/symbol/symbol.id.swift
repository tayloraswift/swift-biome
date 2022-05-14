extension Symbol 
{
    public 
    enum ResolutionError:Error, CustomStringConvertible
    {
        case id(ID)
        
        public 
        var description:String 
        {
            switch self 
            {
            case .id(let id): 
                return "could not resolve symbol '\(id.string)' (\(id.description))"
            }
        }
    }
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }
    struct ID:Hashable, CustomStringConvertible, Sendable 
    {
        let string:String 
        
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
        
        var description:String
        {
            Demangle[self.string]
        }
    }
}
