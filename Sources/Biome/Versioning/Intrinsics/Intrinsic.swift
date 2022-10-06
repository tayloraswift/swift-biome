public 
protocol Intrinsic<Culture, Offset>
{
    associatedtype Offset:UnsignedInteger where Offset.Stride == Int
    associatedtype Culture:Hashable
}