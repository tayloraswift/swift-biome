extension Branch.Position where Element.Culture == Package.Index
{
    var package:Package.Index 
    {
        self.culture 
    }
}
extension Branch.Position where Element.Culture == Branch.Position<Module>
{
    var package:Package.Index
    {
        self.culture.package
    }
    var module:Branch.Position<Module>
    {
        self.culture 
    }
}
extension Branch.Position:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Branch 
{
    @frozen public 
    struct Position<Element>:Hashable, Comparable where Element:BranchElement
    {
        public 
        let culture:Element.Culture
        public 
        let offset:Element.Offset
        
        @inlinable public 
        init(_ culture:Element.Culture, offset:Element.Offset)
        {
            self.culture = culture
            self.offset = offset
        }

        @inlinable public static 
        func == (lhs:Self, rhs:Self) -> Bool
        {
            lhs.offset == rhs.offset && lhs.culture == rhs.culture 
        }
        @inlinable public static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.offset < rhs.offset
        }
        @inlinable public 
        func hash(into hasher:inout Hasher)
        {
            self.culture.hash(into: &hasher)
            self.offset.hash(into: &hasher)
        }

        // @inlinable public
        // func advanced(by stride:Offset.Stride) -> Self 
        // {
        //     .init(self.culture, offset: self.offset.advanced(by: stride))
        // }
        // @inlinable public
        // func distance(to other:Self) -> Offset.Stride
        // {
        //     self.offset.distance(to: other.offset)
        // }
    }
}

extension Branch 
{
    struct Diacritic:Hashable, Sendable
    {
        let host:Position<Symbol> 
        let culture:Symbol.Culture
        
        init(host:Position<Symbol>, culture:Symbol.Culture)
        {
            self.host = host 
            self.culture = culture
        }
        
        init(natural:Position<Symbol>)
        {
            self.host = natural 
            self.culture = natural.module
        }

        func inflect(_ bases:Set<Tree.Position<Symbol>>, 
            namespace:Position<Module>, 
            stem:Route.Stem,
            context:Packages)
            -> Route.Cohort.Synthetics 
        {
            .init(namespace: namespace, stem: stem, diacritic: self, matrix: bases.map 
            { 
                ($0.contemporary, context[global: $0].route.leaf) 
            })
        }
    }

    // 20 B size, 24 B stride
    @usableFromInline
    struct Composite:Hashable, Sendable
    {
        //  there are up to three cultures that come into play here:
        //  1. host culture 
        //  2. witness culture 
        //  3. perpetrator culture
        let base:Position<Symbol>
        let diacritic:Diacritic 
        
        var culture:Position<Module>
        {
            self.diacritic.culture
        }
        var isNatural:Bool 
        {
            self.base == self.diacritic.host
        }
        var host:Position<Symbol>? 
        {
            self.isNatural ? nil : self.diacritic.host 
        }
        var natural:Position<Symbol>? 
        {
            self.isNatural ? self.base : nil
        }
        
        init(natural:Position<Symbol>) 
        {
            self.base = natural
            self.diacritic = .init(natural: natural)
        }
        init(_ base:Position<Symbol>, _ diacritic:Diacritic) 
        {
            self.base = base 
            self.diacritic = diacritic
        }
    }
}
