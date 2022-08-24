import SymbolGraphs
import Versions
import Grammar 

extension Symbol.Link 
{
    struct Lens 
    {
        let culture:Package.ID, 
            version:MaskedVersion?
        
        init(_ culture:Package.ID, at version:MaskedVersion? = nil)
        {
            self.culture = culture 
            self.version = version
        }
    }
    struct Query 
    {
        static 
        let base:String = "overload", 
            host:String = "self", 
            lens:String = "from"
        
        var base:Symbol.ID?
        var host:Symbol.ID?
        var lens:Lens?
        
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
                        let version:MaskedVersion = try? .init(parsing: second)
                    {
                        self.lens = .init(id, at: version)
                    }
                    else 
                    {
                        self.lens = .init(id)
                    }
                
                case Self.host:
                    // if the mangled name contained a colon ('SymbolGraphGen style'), 
                    // the parsing rule will remove it.
                    self.host = try USR.Rule<String.Index>.OpaqueName.parse(value.utf8)
                
                case Self.base: 
                    switch try USR.init(parsing: value.utf8) 
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
