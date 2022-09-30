import DOM
import URI 

@frozen public 
struct CaselessString:Hashable, Sendable
{
    public 
    let lowercased:String 

    @inlinable public
    init(lowercased:String)
    {
        self.lowercased = lowercased
    }

    @inlinable public
    init(_ string:String)
    {
        self.init(lowercased: string.lowercased())
    }

    init(_ namespace:Module.ID)
    {
        self.init(lowercased: namespace.value)
    }
}
extension CaselessString:ExpressibleByStringLiteral 
{
    @inlinable public 
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}

extension Service 
{
    public 
    enum PublicFunction 
    {
        case documentation(Scheme)
        case sitemap 
        case lunr 

        struct Names 
        {
            var sitemap:CaselessString, 
                lunr:CaselessString, 
                doc:CaselessString,
                symbol:CaselessString
            
            init() 
            {
                self.sitemap = "sitemaps"
                self.lunr = "lunr"
                self.doc = "learn"
                self.symbol = "reference"
            }
        }
    }
    struct CustomFunction 
    {
        let nationality:Packages.Index
        // store a module identifier instead of a position or atom, 
        // to make this more resilient against version editing
        let namespace:Module.ID
        let template:DOM.Flattened<PageElement> 
    }
    enum Function 
    {
        case `public`(PublicFunction)
        case custom(CustomFunction)
    }

    struct Functions 
    {
        private 
        var table:[CaselessString: Function]
        private(set)
        var names:PublicFunction.Names
        
        subscript(key:String) -> Function?
        {
            self.table[.init(key)]
        }

        init()
        {
            self.names = .init()

            self.table = 
            [
                self.names.sitemap: .public(.sitemap),
                self.names.lunr:    .public(.lunr),
                self.names.doc:     .public(.documentation(.doc)),
                self.names.symbol:  .public(.documentation(.symbol)),
            ]
        }
        init(_ table:[String: PublicFunction])
        {
            self.init()
            for (name, function):(String, PublicFunction) in table 
            {
                let name:CaselessString = .init(name)
                self.table[name] = .public(function)
                switch function 
                {
                case .sitemap: 
                    self.names.sitemap = name 
                case .lunr: 
                    self.names.lunr = name 
                case .documentation(.doc): 
                    self.names.doc = name 
                case .documentation(.symbol): 
                    self.names.symbol = name 
                }
            }
        }

        mutating 
        func create(_ namespace:Module.ID, 
            nationality:Packages.Index, 
            template:DOM.Flattened<PageElement>) -> Bool 
        {
            let key:CaselessString = .init(namespace) 
            if self.table.keys.contains(key)
            {
                return false 
            }
            else 
            {
                self.table[key] = .custom(.init(
                    nationality: nationality, 
                    namespace: namespace, 
                    template: template))
                return true 
            }
        }
    }
}
extension Service.PublicFunction.Names
{
    func uri(_ function:Service.PublicFunction) -> URI
    {
        switch function 
        {
        case .sitemap:                  return .init(root: self.sitemap.lowercased)
        case .lunr:                     return .init(root: self.lunr.lowercased)
        case .documentation(.doc):      return .init(root: self.doc.lowercased)
        case .documentation(.symbol):   return .init(root: self.symbol.lowercased)
        }
    }
}