extension Package 
{
    enum ResolutionError:Error 
    {
        case dependency(ID, of:ID)
    }
    public 
    struct ID:Hashable, Comparable, Sendable, Decodable, ExpressibleByStringLiteral, CustomStringConvertible
    {
        public 
        enum Kind:Hashable, Comparable, Sendable 
        {
            case swift 
            case core
            case community(String)
        }
        
        @usableFromInline
        let kind:Kind 
        
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.kind < rhs.kind
        }
        
        public static 
        let swift:Self = .init(kind: .swift)
        public static 
        let core:Self = .init(kind: .core)
        
        public 
        var string:String 
        {
            switch self.kind
            {
            case .swift:                return "swift-standard-library"
            case .core:                 return "swift-core-libraries"
            case .community(let name):  return name 
            }
        }
        public 
        var description:String 
        {
            switch self.kind
            {
            case .swift:                return "swift"
            case .core:                 return "swift-core-libraries"
            case .community(let name):  return name 
            }
        }
        
        @inlinable public 
        init(from decoder:any Decoder) throws 
        {
            self.init(try decoder.singleValueContainer().decode(String.self))
        }
        public 
        init(stringLiteral:String)
        {
            self.init(stringLiteral)
        }
        @inlinable public
        init<S>(_ string:S) where S:StringProtocol
        {
            switch string.lowercased() 
            {
            case    "swift-standard-library",
                    "standard-library",
                    "swift-stdlib",
                    "stdlib":
                self.init(kind: .swift)
            case let name:
                self.init(kind: .community(name))
            }
        }
        
        @inlinable public 
        init(kind:Kind)
        {
            self.kind = kind
        }
        
        @available(*, deprecated, renamed: "string")
        public 
        var name:String 
        {
            self.string 
        }
    }
}
