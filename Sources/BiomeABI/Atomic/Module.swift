@frozen public 
struct Module:AtomicReference, Sendable
{
    public
    let offset:UInt16
    public
    let culture:Package

    @inlinable public 
    init(_ culture:Package, offset:UInt16)
    {
        self.culture = culture
        self.offset = offset
    }
}
