struct Fascis:Sendable 
{
    private
    let _articles:Branch.Buffer<Article>.SubSequence, 
        _symbols:Branch.Buffer<Symbol>.SubSequence,
        _modules:Branch.Buffer<Module>.SubSequence 
    private 
    let _opinions:[Branch.Diacritic: _ForeignDivergence], 
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
        opinions:[Branch.Diacritic: _ForeignDivergence],
        routes:[Route.Key: Branch.Stack],
        branch:_Version.Branch, 
        limit:_Version.Revision)
    {
        self._articles = articles
        self._symbols = symbols
        self._modules = modules
        self._routes = routes
        self._opinions = opinions

        self.branch = branch
        self.limit = limit
    }

    var articles:Branch.Epoch<Article> 
    {
        .init(self._articles, branch: self.branch, limit: self.limit)
    }
    var symbols:Branch.Epoch<Symbol> 
    {
        .init(self._symbols, branch: self.branch, limit: self.limit)
    }
    var modules:Branch.Epoch<Module> 
    {
        .init(self._modules, branch: self.branch, limit: self.limit)
    }
    var opinions:Divergences<Branch.Diacritic, _ForeignDivergence> 
    {
        .init(self._opinions, limit: self.limit)
    }
    var routes:Divergences<Route.Key, Branch.Stack> 
    {
        .init(self._routes, limit: self.limit)
    }
}

// extension RandomAccessCollection<Fascis>
// {
//     func pluralize(_ position:Branch.Position<Symbol>) -> Tree.Position<Symbol>?
//     {
//         self.pluralize(position, in: \.symbols)
//     }
//     private 
//     func pluralize<T>(_ position:Branch.Position<T>, 
//         in buffer:KeyPath<Fascis, Branch.Buffer<T>.SubSequence>) -> Tree.Position<T>?
//         where T:BranchElement 
//     {
//         let fascis:Fascis? = self.search 
//         {
//             if      position.offset < $0[keyPath: buffer].indices.lowerBound 
//             {
//                 return .lower 
//             }
//             else if position.offset < $0[keyPath: buffer].indices.upperBound 
//             {
//                 return nil 
//             }
//             else 
//             {
//                 return .upper
//             }
//         }
//         return fascis?.branch.pluralize(position)
//     }
// }

// private
// enum BinarySearchPartition 
// {
//     case lower 
//     case upper
// }
// extension RandomAccessCollection 
// {
//     private
//     func search(by partition:(Element) throws -> BinarySearchPartition?) rethrows -> Element?
//     {
//         var count:Int = self.count
//         var current:Index = self.startIndex
        
//         while 0 < count
//         {
//             let half:Int = count >> 1
//             let median:Index = self.index(current, offsetBy: half)

//             let element:Element = self[median]
//             switch try partition(element)
//             {
//             case .lower?:
//                 count = half
//             case nil: 
//                 return element
//             case .upper?:
//                 current = self.index(after: median)
//                 count -= half + 1
//             }
//         }
//         return nil
//     }
// }