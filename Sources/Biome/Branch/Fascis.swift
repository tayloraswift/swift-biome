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
extension RandomAccessCollection<Fascis>
{
    func pluralize(_ position:Branch.Position<Symbol>) -> Tree.Position<Symbol>?
    {
        self.pluralize(position, in: \.symbols)
    }
    private 
    func pluralize<T>(_ position:Branch.Position<T>, 
        in buffer:KeyPath<Fascis, Branch.Buffer<T>.SubSequence>) -> Tree.Position<T>?
        where T:BranchElement 
    {
        let fascis:Fascis? = self.search 
        {
            if      position.offset < $0[keyPath: buffer].indices.lowerBound 
            {
                return .lower 
            }
            else if position.offset < $0[keyPath: buffer].indices.upperBound 
            {
                return nil 
            }
            else 
            {
                return .upper
            }
        }
        return fascis?.branch.pluralize(position)
    }
}

private
enum BinarySearchPartition 
{
    case lower 
    case upper
}
extension RandomAccessCollection 
{
    private
    func search(by partition:(Element) throws -> BinarySearchPartition?) rethrows -> Element?
    {
        var count:Int = self.count
        var current:Index = self.startIndex
        
        while 0 < count
        {
            let half:Int = count >> 1
            let median:Index = self.index(current, offsetBy: half)

            let element:Element = self[median]
            switch try partition(element)
            {
            case .lower?:
                count = half
            case nil: 
                return element
            case .upper?:
                current = self.index(after: median)
                count -= half + 1
            }
        }
        return nil
    }
}