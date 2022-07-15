import Grammar 

extension Symbol.Link 
{
    struct Query 
    {
        static 
        let base:String = "overload", 
            host:String = "self", 
            lens:String = "from"
        
        var base:Symbol.ID?
        var host:Symbol.ID?
        var lens:(culture:Package.ID, version:MaskedVersion?)?
        
        init() 
        {
            self.base = nil 
            self.host = nil
            self.lens = nil 
        }
        init(_ parameters:[URI.Parameter]) throws 
        {
            self.init()
            try self.update(with: parameters)
        }
        mutating 
        func update(with parameters:[URI.Parameter]) throws 
        {
            for (key, value):(String, String) in parameters 
            {
                switch key
                {
                case Self.lens:
                    // either 'from=swift-foo' or 'from=swift-foo/0.1.2'. 
                    // we do not tolerate missing slashes
                    let components:[Substring] = value.split(separator: "/")
                    guard let first:Substring = components.first
                    else 
                    {
                        continue  
                    }
                    let id:Package.ID = .init(first)
                    if  let second:Substring = components.dropFirst().first, 
                        let version:MaskedVersion = try? Grammar.parse(second.unicodeScalars, 
                            as: MaskedVersion.Rule<String.Index>.self)
                    {
                        self.lens = (id, version)
                    }
                    else 
                    {
                        self.lens = (id, nil)
                    }
                
                case Self.host:
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.host = try Grammar.parse(value.utf8, as: USR.Rule<String.Index>.OpaqueName.self)
                
                case Self.base: 
                    switch try Grammar.parse(value.utf8, as: USR.Rule<String.Index>.self) 
                    {
                    case .natural(let base):
                        self.base = base
                    
                    case .synthesized(from: let base, for: let host):
                        // this is supported for backwards-compatibility, 
                        // but the `::SYNTHESIZED::` infix is deprecated, 
                        // so this will end up causing a redirect 
                        self.host = host
                        self.base = base 
                    }

                default: 
                    continue  
                }
            }
        }
    }
}
