struct Fascis:Sendable 
{
    private
    let _articles:Branch.Buffer<Article>.SubSequence, 
        _symbols:Branch.Buffer<Symbol>.SubSequence,
        _modules:Branch.Buffer<Module>.SubSequence 
    private 
    let _foreign:[Diacritic: Symbol.ForeignDivergence], 
        _routes:[Route: Branch.Stack]
    /// The last version contained within this fascis.
    let latest:Version
    /// The version this fascis (and its original branch) was forked from.
    let fork:Version?

    init(
        articles:Branch.Buffer<Article>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        modules:Branch.Buffer<Module>.SubSequence, 
        foreign:[Diacritic: Symbol.ForeignDivergence],
        routes:[Route: Branch.Stack],
        branch:Version.Branch, 
        limit:Version.Revision, 
        fork:Version?)
    {
        self._articles = articles
        self._symbols = symbols
        self._modules = modules
        self._foreign = foreign
        self._routes = routes

        self.latest = .init(branch, limit)
        self.fork = nil
    }
    /// The index of the original branch this fascis was cut from.
    /// 
    /// This is the branch that contains the fascis, not the branch 
    /// the fascis was forked from.
    var branch:Version.Branch 
    {
        self.latest.branch
    }
    /// The index of the last revision contained within this fascis.
    var limit:Version.Revision 
    {
        self.latest.revision
    }

    var articles:Epoch<Article> 
    {
        .init(self._articles, latest: self.latest, fork: self.fork)
    }
    var symbols:Epoch<Symbol> 
    {
        .init(self._symbols, latest: self.latest, fork: self.fork)
    }
    var modules:Epoch<Module> 
    {
        .init(self._modules, latest: self.latest, fork: self.fork)
    }
    var foreign:Divergences<Diacritic, Symbol.ForeignDivergence> 
    {
        .init(self._foreign, latest: self.latest, fork: self.fork)
    }
    var routes:Divergences<Route, Branch.Stack> 
    {
        .init(self._routes, latest: self.latest, fork: self.fork)
    }
}
