extension GlobalLink 
{
    enum Target:Hashable, Sendable 
    {
        case article(Branch.Position<Article>)
        case module(Branch.Position<Module>)
        case package(Package.Index)
        case composite(Branch.Composite)

        init(_ resolution:_SymbolLink.Resolution?) throws 
        {
            switch resolution 
            {
            case nil: 
                throw _SymbolLink.ResolutionProblem.noResults
            case .module(let module): 
                self = .module(module)
            case .composite(let composite): 
                self = .composite(composite)
            case .composites(let composites): 
                throw _SymbolLink.ResolutionProblem.multipleResults(composites)
            }
        }
    }
    enum TargetExpansion:Hashable, Sendable 
    {
        case article(PluralPosition<Article>)
        case package(Package.Index)
        case implicit                         ([PluralPosition<Symbol>])
        case qualified(PluralPosition<Module>, [PluralPosition<Symbol>] = [])
    }

    enum Presentation:Hashable, Sendable
    {
        case article(Branch.Position<Article>)
        case module(Branch.Position<Module>)
        case package(Package.Index)
        case composite(Branch.Composite, visible:Int)

        init(_ target:Target, visible:Int)
        {
            switch target 
            {
            case .article(let article):
                self = .article(article)
            case .module(let module):
                self = .module(module)
            case .package(let package):
                self = .package(package)
            case .composite(let composite):
                self = .composite(composite, visible: visible)
            }
        }
    }
}

extension _SymbolLink 
{
    enum ResolutionProblem:Error 
    {
        case empty
        case scheme 
        case residency
        // case residentVersion
        case nationality
        case nationalVersion

        case noResults
        case multipleResults([Branch.Composite])
    }
    struct ResolutionError:Error 
    {
        let link:String 
        let problem:any Error 

        init(_ link:String, _ error:any Error)
        {
            self.link = link 
            self.problem = error
        }
        init(_ link:String, problem:ResolutionProblem)
        {
            self.link = link 
            self.problem = problem
        }
    }

    enum Resolution 
    {
        //case package(Package.Index)
        case module(Branch.Position<Module>)
        case composite(Branch.Composite) 
        case composites([Branch.Composite]) 

        init(_ selection:_Selection<Branch.Composite>)
        {
            switch selection 
            {
            case .one(let composite): 
                self = .composite(composite)
            case .many(let composites): 
                self = .composites(composites)
            }
        }
    }
}