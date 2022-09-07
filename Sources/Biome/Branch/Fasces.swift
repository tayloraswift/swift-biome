struct Fasces
{
    struct ModuleView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Branch.Epoch<Module> 
        {
            self.segments[index].modules
        }
    }
    struct SymbolView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Branch.Epoch<Symbol>
        {
            self.segments[index].symbols
        }
    }
    struct ArticleView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Branch.Epoch<Article> 
        {
            self.segments[index].articles
        }
    }

    private
    var segments:[Fascis]

    init() 
    {
        self.segments = []
    }
    init(_ segments:__owned [Fascis])
    {
        self.segments = segments
    }

    var modules:ModuleView 
    {
        .init(self.segments)
    }
    var symbols:SymbolView 
    {
        .init(self.segments)
    }
    var articles:ArticleView 
    {
        .init(self.segments)
    }
}
extension Fasces:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:Fascis...)
    {
        self.init(arrayLiteral)
    }
}
extension Fasces:RandomAccessCollection, RangeReplaceableCollection 
{
    var startIndex:Int 
    {
        self.segments.startIndex
    }
    var endIndex:Int 
    {
        self.segments.endIndex
    }
    subscript(index:Int) -> Fascis
    {
        _read 
        {
            yield self.segments[index]
        }
    }
    mutating 
    func replaceSubrange(_ subrange:Range<Int>, with elements:some Collection<Fascis>) 
    {
        self.segments.replaceSubrange(subrange, with: elements)
    }
}

extension Sequence<Branch.Epoch<Module>>
{
    func find(_ module:Module.ID) -> Tree.Position<Module>? 
    {
        for modules:Branch.Epoch<Module> in self 
        {
            if let module:Branch.Position<Module> = modules.position(of: module)
            {
                return modules.branch.pluralize(module)
            }
        }
        return nil
    }
}
extension Sequence<Branch.Epoch<Symbol>>
{
    func find(_ symbol:Symbol.ID) -> Tree.Position<Symbol>? 
    {
        for symbols:Branch.Epoch<Symbol> in self 
        {
            if let symbol:Branch.Position<Symbol> = symbols.position(of: symbol)
            {
                return symbols.branch.pluralize(symbol)
            }
        }
        return nil
    }
}
extension Sequence<Branch.Epoch<Article>>
{
    func find(_ article:Article.ID) -> Tree.Position<Article>? 
    {
        for articles:Branch.Epoch<Article> in self 
        {
            if let article:Branch.Position<Article> = articles.position(of: article)
            {
                return articles.branch.pluralize(article)
            }
        }
        return nil
    }
}