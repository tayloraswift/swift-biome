extension Link 
{
    enum Component 
    {
        case identifier(String, hyphen:String.Index? = nil)
        case version(Version)
        
        var version:Version?
        {
            switch self 
            {
            case .identifier(_, hyphen: _):
                return nil
            case .version(let version): 
                return version
            }
        }
        var identifier:String?
        {
            switch self 
            {
            case .identifier(let string, hyphen: _):
                return string
            case .version(_): 
                return nil
            }
        }
        var prefix:String?
        {
            switch self 
            {
            case .identifier(let string, hyphen: nil):
                return       string
            case .identifier(let string, hyphen: let hyphen?):
                return .init(string[..<hyphen])
            case .version(_): 
                return nil
            }
        }
        var suffix:Suffix?
        {
            if case .identifier(let string, hyphen: let hyphen?) = self 
            {
                return .init(string[hyphen...].dropFirst())
            }
            else 
            {
                return nil 
            }
        }
    }
    enum Suffix 
    {
        case color(Symbol.Color)
        case fnv(hash:UInt32)
        
        fileprivate
        init?<S>(_ string:S) where S:StringProtocol 
        {
            // will never collide with symbol colors, since they always contain 
            // a period ('.')
            // https://github.com/apple/swift-docc/blob/d94139a5e64e9ecf158214b1cded2a2880fc1b02/Sources/SwiftDocC/Utility/FoundationExtensions/String%2BHashing.swift
            if let hash:UInt32 = .init(string, radix: 36)
            {
                self = .fnv(hash: hash)
            }
            else if let color:Symbol.Color = .init(rawValue: String.init(string))
            {
                self = .color(color)
            }
            else 
            {
                return nil
            }
        }
    }
}
