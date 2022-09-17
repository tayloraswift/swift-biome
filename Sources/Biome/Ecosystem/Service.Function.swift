import URI 

extension Service 
{
    public 
    enum Function 
    {
        case documentation(Scheme)
        case sitemap 
        case lunr 
    }

    struct Functions 
    {
        private 
        let table:[String: Function]
        private
        var sitemap:String, 
            lunr:String, 
            doc:String,
            symbol:String
        
        subscript(key:String) -> Function?
        {
            self.table[key.lowercased()]
        }

        init(_ table:[String: Function])
        {
            self.sitemap = "sitemaps"
            self.lunr = "lunr"
            self.doc = "learn"
            self.symbol = "reference"

            for (name, function):(String, Function) in table 
            {
                let name:String = name.lowercased()
                switch function 
                {
                case .sitemap: 
                    self.sitemap = name 
                case .lunr: 
                    self.lunr = name 
                case .documentation(.doc): 
                    self.doc = name 
                case .documentation(.symbol): 
                    self.symbol = name 
                }
            }
            self.table = 
            [
                self.sitemap: .sitemap,
                self.lunr: .lunr,
                self.doc: .documentation(.doc),
                self.symbol: .documentation(.symbol),
            ]
        }
    }
}
extension Service.Functions 
{
    func uri(_ function:Service.Function) -> URI
    {
        switch function 
        {
        case .sitemap:                  return .init(root: self.sitemap)
        case .lunr:                     return .init(root: self.lunr)
        case .documentation(.doc):      return .init(root: self.doc)
        case .documentation(.symbol):   return .init(root: self.symbol)
        }
    }
}