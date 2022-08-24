import Grammar
import JSON

extension SymbolIdentifier
{
    init(from json:JSON) throws 
    {
        self = try USR.Rule<String.Index>.OpaqueName.parse(try json.as(String.self).utf8)
    }
    
    var interface:(culture:ModuleIdentifier, protocol:(name:String, id:Self))?
    {
        // if a vertex is non-canonical, the symbol id of its generic base 
        // always starts with a mangled protocol name. 
        // note that our demangling implementation cannot handle “known” 
        // protocols like 'Swift.Equatable'. but this is fine because we 
        // are only using this to detect symbols that are defined in extensions 
        // on underscored protocols.
        var input:ParsingInput<NoDiagnostics> = .init(self.string.utf8)
        guard case let (namespace, name)? = 
            input.parse(as: USR.Rule<String.Index>.MangledProtocolName?.self)
        else 
        {
            return nil 
        }
        // parsing input shares indices with `self.string`. we can use the 
        // unsafe `init(unchecked:)` because `USR.Rule.MangledProtocolName` 
        // only succeeds if the first character is a lowercase 's'
        let id:Self = .init(unchecked: .init(self.string[..<input.index]))
        let culture:ModuleIdentifier = 
            input.parse(as: USR.Rule<String.Index>.MangledExtensionContext?.self) ?? namespace
        return (culture, (name, id))
    }
}
