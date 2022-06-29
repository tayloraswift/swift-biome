import JSON

extension Symbol.ID 
{
    init(from json:JSON) throws 
    {
        let string:String = try json.as(String.self)
        self = try Grammar.parse(string.utf8, as: USR.Rule<String.Index>.OpaqueName.self)
    }
    
    var interface:(culture:Module.ID, protocol:(name:String, id:Self))?
    {
        // if a vertex is non-canonical, the symbol id of its generic base 
        // always starts with a mangled protocol name. 
        // note that our demangling implementation cannot handle “known” 
        // protocols like 'Swift.Equatable'. but this is fine because we 
        // are only using this to detect symbols that are defined in extensions 
        // on underscored protocols.
        var input:ParsingInput<Grammar.NoDiagnostics> = .init(self.string.utf8)
        guard case let (namespace, name)? = 
            input.parse(as: USR.Rule<String.Index>.MangledProtocolName?.self)
        else 
        {
            return nil 
        }
        // parsing input shares indices with `self.string`
        let id:Self = .init(string: .init(self.string[..<input.index]))
        let culture:Module.ID = 
            input.parse(as: USR.Rule<String.Index>.MangledExtensionContext?.self) ?? namespace
        return (culture, (name, id))
    }
}
