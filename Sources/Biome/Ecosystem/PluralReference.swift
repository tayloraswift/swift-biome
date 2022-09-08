import URI 

//  /colony/arrival/namespace.symbol(_:)?from=package/departure
//  /arrival/namespace.symbol(_:)?from=package/departure
//  /namespace.symbol(_:)?from=package/departure
struct PluralReference 
{
    enum Parameter:String 
    {
        case base     = "overload"
        case host     = "self"
        case culture  = "from"
    }
    
    let namespaces:[Package]
    private(set)
    var culture:Package._Pinned?

    let path:ArraySlice<String>
    private(set)
    var base:Symbol.ID?, 
        host:Symbol.ID?

    init?<Components>(path:Components, query:[URI.Parameter], context:__shared Packages)
        where Components:Collection, Components.SubSequence == ArraySlice<String>
    {
        guard let first:Package.ID = path.first.map(Package.ID.init(_:))
        else 
        {
            return nil
        }
        if let namespace:Package = context[first]
        {
            self.namespaces = [namespace]
            self.path = path.dropFirst()
        }
        else 
        {
            switch (context[.swift], context[.core])
            {
            case (nil, nil): 
                return nil
            case (let first?, nil), (nil, let first?): 
                self.namespaces = [first]
            case (let first?, let second?): 
                self.namespaces = [first, second]
            }
            self.path = path[...]
        }

        self.culture = nil 
        self.base = nil 
        self.host = nil

        self.update(with: query, context: context)
    }

    private mutating 
    func update(with parameters:some Sequence<URI.Parameter>, context:Packages) 
    {
        for (key, value):(String, String) in parameters 
        {
            switch Parameter.init(rawValue: key)
            {
            case nil: 
                continue 
            
            case .culture?:
                // either 'from=swift-foo' or 'from=swift-foo/0.1.2'. 
                // we do not tolerate missing slashes
                var separator:String.Index = value.firstIndex(of: "/") ?? value.endIndex
                guard let package:Package = context[.init(value[..<separator])]
                else 
                {
                    continue  
                }
                while separator < value.endIndex, value[separator] != "/"
                {
                    value.formIndex(after: &separator)
                }
                let version:_Version? = separator < value.endIndex ?
                    package.tree.find(.init(parsing: value[separator...])) : nil 
                if let version:_Version = version ?? package.tree.default
                {
                    self.culture = .init(package, version: version)
                }
            
            case .host?:
                // if the mangled name contained a colon ('SymbolGraphGen style'), 
                // the parsing rule will remove it.
                if  let host:Symbol.ID = 
                        try? USR.Rule<String.Index>.OpaqueName.parse(value.utf8)
                {
                    self.host = host
                }
            
            case .base?: 
                switch try? USR.init(parsing: value.utf8) 
                {
                case nil: 
                    continue 
                
                case .natural(let base)?:
                    self.base = base
                
                case .synthesized(from: let base, for: let host)?:
                    // this is supported for backwards-compatibility, 
                    // but the `::SYNTHESIZED::` infix is deprecated, 
                    // so this will end up causing a redirect 
                    self.host = host
                    self.base = base 
                }
            }
        }
    }
}