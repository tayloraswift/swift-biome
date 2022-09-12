extension Tree.Position:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Tree 
{
    struct Position<Element>:Hashable where Element:BranchElement
    {
        let contemporary:Branch.Position<Element>
        let branch:_Version.Branch 

        @available(*, deprecated, renamed: "contemporary")
        var index:Element.Index 
        {
            self.contemporary
        }

        init(_ contemporary:Branch.Position<Element>, branch:_Version.Branch)
        {
            self.contemporary = contemporary 
            self.branch = branch
        }
    }
}
extension Tree.Position where Element.Culture == Branch.Position<Module>
{
    var package:Package.Index 
    {
        self.contemporary.module.package
    }
    @available(*, unavailable, 
        message: "a module does not necessarily reside in the same branch segment as its symbols")
    var module:Tree.Position<Module>
    {
        fatalError()
    }
}
extension Tree.Position<Module> 
{
    var package:Package.Index 
    {
        self.contemporary.package
    }
}
extension Tree 
{
    struct Diacritic:Hashable, Sendable
    {
        let host:Position<Symbol>
        let culture:Branch.Position<Module>

        var contemporary:Branch.Diacritic 
        {
            .init(host: self.host.contemporary, culture: self.culture)
        }
        
        init(host:Position<Symbol>, culture:Branch.Position<Module>)
        {
            self.host = host 
            self.culture = culture
        }
        
        init(natural:Position<Symbol>)
        {
            self.host = natural 
            self.culture = natural.contemporary.culture
        }
    }
    struct Composite:Hashable, Sendable
    {
        let base:Branch.Position<Symbol>
        let diacritic:Diacritic 

        var culture:Branch.Position<Module>
        {
            self.diacritic.culture
        }

        var isNatural:Bool 
        {
            // only need to compare the contemporary portions
            self.base == self.diacritic.host.contemporary
        }
        var host:Position<Symbol>? 
        {
            self.isNatural ? nil : self.diacritic.host 
        }
        var natural:Position<Symbol>? 
        {
            self.isNatural ? self.diacritic.host : nil
        }
    }
}
