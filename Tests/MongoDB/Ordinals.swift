struct Ordinals:Sendable
{
    let identifiers:Range<Int>
    let start:Int64

    init(identifiers:Range<Int>, start:Int64 = 0)
    {
        self.identifiers = identifiers
        self.start = start
    }
}
extension Ordinals:RandomAccessCollection
{
    var startIndex:Int
    {
        self.identifiers.lowerBound
    }
    var endIndex:Int
    {
        self.identifiers.upperBound
    }
    subscript(index:Int) -> Ordinal
    {
        .init(id: index, value: self.start + Int64.init(index))
    }
}
