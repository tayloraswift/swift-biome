extension _SymbolLink 
{
    struct ResolutionError:Error 
    {
        enum Problem:Error 
        {
            case empty
            case scheme 
        }

        let link:String 
        let problem:any Error 

        init(_ link:String, _ error:any Error)
        {
            self.link = link 
            self.problem = error
        }
        init(_ link:String, problem:Problem)
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

    enum Target:Hashable, Sendable 
    {
        case article(Branch.Position<Article>)
        case module(Branch.Position<Module>)
        case package(Package.Index)
        case composite(Branch.Composite)
    }
    enum TargetExpansion:Hashable, Sendable 
    {
        case article(Tree.Position<Article>)
        case package(Package.Index)
        case implicit                        ([Tree.Position<Symbol>])
        case qualified(Tree.Position<Module>, [Tree.Position<Symbol>] = [])
    }

    struct Presentation:Hashable, Sendable
    {
        let target:Target
        let visible:Int
        
        init(_ target:Target, visible:Int)
        {
            self.target = target 
            self.visible = visible
        }
    }
}