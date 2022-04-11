extension Symbol 
{
    enum USR:Hashable, Sendable 
    {
        case natural(ID)
        case synthesized(from:ID, for:ID)
    }
    enum ID:Hashable, CustomStringConvertible, Sendable 
    {
        case swift([UInt8])
        case c([UInt8])
        
        var string:String 
        {
            switch self 
            {
            case .swift(let utf8): 
                return "s\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
            case .c(let utf8):
                return "c\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
            }
        }
        /* 
        init(_ string:String)
        {
            self.string = string 
        }
         */
        var description:String
        {
            switch self 
            {
            case .swift(let utf8):
                return Demangle[utf8]
            case .c(let utf8): 
                return "c-language symbol '\(String.init(decoding: utf8, as: Unicode.UTF8.self))'"
            }
        }
    }
}
