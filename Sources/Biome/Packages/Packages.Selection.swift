import Versions 

extension Packages 
{
    @usableFromInline
    enum Selection
    {
        case one(Branch.Composite)
        case many([Branch.Composite])
                
        init?(_ matches:[Branch.Composite]) 
        {
            guard let first:Branch.Composite = matches.first 
            else 
            {
                return nil
            }
            if matches.count < 2
            {
                self = .one(first)
            } 
            else 
            {
                self = .many(matches)
            }
        }
        
        func composite() throws -> Branch.Composite 
        {
            switch self 
            {
            case .one(let composite):
                return composite 
            case .many(let composites): 
                throw SelectionError.many(composites)
            }
        }
    }
}

