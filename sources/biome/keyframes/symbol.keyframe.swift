import Notebook

extension Symbol 
{
    enum Legality:Hashable, Sendable 
    {
        // we must store the comment, otherwise packages that depend on the package 
        // this symbol belongs to will not be able to reliably de-duplicate documentation
        static 
        let undocumented:Self = .documented("")
        
        case documented(String)
        case sponsored(by:Symbol.Index)
    }
}
