import Grammar

enum Link:Hashable, Sendable
{
    case resolved(Target, visible:Int)
    case unresolved(String)
}
extension Link 
{
    enum Resolution
    {
        case one(Target)
        case many([Symbol.Composite])
        
        init?(_ matches:[Symbol.Composite]) 
        {
            guard let first:Symbol.Composite = matches.first 
            else 
            {
                return nil
            }
            if matches.count < 2
            {
                self = .one(.composite(first))
            } 
            else 
            {
                self = .many(matches)
            }
        }
    }
    enum Target:Hashable 
    {
        case package(Package.Index)
        case module(Module.Index)
        case article(Article.Index)
        case composite(Symbol.Composite)
        
        static 
        func symbol(_ natural:Symbol.Index) -> Self 
        {
            .composite(.init(natural: natural))
        }
    }
    struct Disambiguator 
    {
        let host:Symbol.ID?
        let symbol:Symbol.ID?
        let suffix:Suffix?
    }
}
