extension _SymbolLink 
{
    enum Resolution 
    {
        case package(Package.Index)
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