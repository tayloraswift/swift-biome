struct Fascis:Sendable 
{
    private
    let _articles:Branch.Buffer<Article>.SubSequence, 
        _symbols:Branch.Buffer<Symbol>.SubSequence,
        _modules:Branch.Buffer<Module>.SubSequence 
    private 
    let _foreign:[Branch.Diacritic: Symbol.ForeignDivergence], 
        _routes:[Route.Key: Branch.Stack]
    /// The index of the original branch this fascis was cut from.
    /// 
    /// This is the branch that contains the fascis, not the branch 
    /// the fascis was forked from.
    let branch:_Version.Branch
    /// The index of the last revision contained within this fascis.
    let limit:_Version.Revision 

    init(
        articles:Branch.Buffer<Article>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        modules:Branch.Buffer<Module>.SubSequence, 
        foreign:[Branch.Diacritic: Symbol.ForeignDivergence],
        routes:[Route.Key: Branch.Stack],
        branch:_Version.Branch, 
        limit:_Version.Revision)
    {
        self._articles = articles
        self._symbols = symbols
        self._modules = modules
        self._foreign = foreign
        self._routes = routes

        self.branch = branch
        self.limit = limit
    }

    var articles:Epoch<Article> 
    {
        .init(self._articles, branch: self.branch, limit: self.limit)
    }
    var symbols:Epoch<Symbol> 
    {
        .init(self._symbols, branch: self.branch, limit: self.limit)
    }
    var modules:Epoch<Module> 
    {
        .init(self._modules, branch: self.branch, limit: self.limit)
    }
    var foreign:Divergences<Branch.Diacritic, Symbol.ForeignDivergence> 
    {
        .init(self._foreign, limit: self.limit)
    }
    var routes:Divergences<Route.Key, Branch.Stack> 
    {
        .init(self._routes, limit: self.limit)
    }
}
