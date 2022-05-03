import Grammar
import JSON

extension Symbol 
{
    enum USR:Hashable, Sendable 
    {
        case natural(ID)
        case synthesized(from:ID, for:ID)
    }
    enum Language:Unicode.Scalar, Hashable, Sendable 
    {
        case c      = "c"
        case swift  = "s"
    }
    struct ID:Hashable, CustomStringConvertible, Sendable 
    {
        let string:String 
        
        init<ASCII>(_ language:Language, _ mangled:ASCII) where ASCII:Sequence, ASCII.Element == UInt8 
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
        
        func isUnderscoredProtocolExtensionMember(from module:Module.ID) -> Bool 
        {
            // if a vertex is non-canonical, the symbol id of its generic base 
            // always starts with a mangled protocol name. 
            // note that our demangling implementation cannot handle “known” 
            // protocols like 'Swift.Equatable'. but this is fine because we 
            // are only using this to detect symbols that are defined in extensions 
            // on underscored protocols.
            var input:ParsingInput<Grammar.NoDiagnostics> = .init(self.string.utf8)
            switch input.parse(as: URI.Rule<String.Index, UInt8>.USR.MangledProtocolName?.self)
            {
            case    (perpetrator: module?, namespace: _,      let name)?, 
                    (perpetrator: nil,     namespace: module, let name)?:
                return name.starts(with: "_") 
            default: 
                return false 
            }
        }
    }
}
extension Symbol.ID 
{
    init(from json:JSON) throws 
    {
        let string:String = try json.as(String.self)
        self = try Grammar.parse(string.utf8, as: URI.Rule<String.Index, UInt8>.USR.OpaqueName.self)
    }
}
