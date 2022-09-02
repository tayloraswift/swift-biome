@available(*, deprecated, renamed: "Fascis")
typealias Trunk = Fascis 

struct Fascis:Sendable 
{
    let branch:_Version.Branch
    let routes:Branch.Table<Route.Key>.Prefix
    let modules:Branch.Buffer<Module>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        articles:Branch.Buffer<Article>.SubSequence
    
    init(branch:_Version.Branch,
        routes:Branch.Table<Route.Key>.Prefix,
        modules:Branch.Buffer<Module>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        articles:Branch.Buffer<Article>.SubSequence)
    {
        self.branch = branch
        self.routes = routes
        self.modules = modules
        self.symbols = symbols
        self.articles = articles
    }
}

extension Sequence<Fascis> 
{
    func find(module:Module.ID) -> Tree.Position<Module>? 
    {
        for fascis:Fascis in self 
        {
            if let module:Branch.Position<Module> = fascis.modules.position(of: module)
            {
                return fascis.branch.pluralize(module)
            }
        }
        return nil
    }
    func find(symbol:Symbol.ID) -> Tree.Position<Symbol>? 
    {
        for fascis:Fascis in self 
        {
            if let symbol:Branch.Position<Symbol> = fascis.symbols.position(of: symbol)
            {
                return fascis.branch.pluralize(symbol)
            }
        }
        return nil
    }
    func find(article:Article.ID) -> Tree.Position<Article>? 
    {
        for fascis:Fascis in self 
        {
            if let article:Branch.Position<Article> = fascis.articles.position(of: article)
            {
                return fascis.branch.pluralize(article)
            }
        }
        return nil
    }
}