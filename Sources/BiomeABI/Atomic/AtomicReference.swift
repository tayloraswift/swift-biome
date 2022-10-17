public
protocol AtomicReference:Hashable
{
    associatedtype Culture
    associatedtype Offset:UnsignedInteger where Offset.Stride == Int

    var culture:Culture { get }
    var offset:Offset { get }
}

extension AtomicReference where Culture == Package
{
    @inlinable public
    var nationality:Package
    {
        self.culture 
    }
}
extension AtomicReference where Culture == Module
{
    @inlinable public
    var nationality:Package
    {
        self.culture.culture
    }
}
