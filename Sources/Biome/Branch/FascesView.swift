protocol FascesView:RandomAccessCollection 
{
    var base:Fasces { get }
}
extension FascesView
{
    var startIndex:Int 
    {
        self.base.startIndex
    }
    var endIndex:Int 
    {
        self.base.endIndex
    }
}

extension Fasces
{
    struct Modules:FascesView
    {
        let base:Fasces
    }
    struct Articles:FascesView
    {
        let base:Fasces
    }
    struct Symbols:FascesView
    {
        let base:Fasces
    }
    struct Overlays:FascesView
    {
        let base:Fasces
    }

    var modules:Modules
    {
        .init(base: self)
    }
    var articles:Articles
    {
        .init(base: self)
    }
    var symbols:Symbols
    {
        .init(base: self)
    }
    var overlays:Overlays
    {
        .init(base: self)
    }
}
extension Fasces.Modules:Periods
{
    subscript(index:Int) -> _Period<IntrinsicSlice<Module>>
    {
        self.base[index].modules
    }
}
extension Fasces.Articles:Periods
{
    subscript(index:Int) -> _Period<IntrinsicSlice<Article>>
    {
        self.base[index].articles
    }
}
extension Fasces.Symbols:Periods
{
    subscript(index:Int) -> _Period<IntrinsicSlice<Symbol>>
    {
        self.base[index].symbols
    }
}
extension Fasces.Overlays:Periods
{
    subscript(index:Int) -> _Period<Overlays>
    {
        self.base[index].overlays
    }
}
