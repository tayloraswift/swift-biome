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
        private(set) 
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
