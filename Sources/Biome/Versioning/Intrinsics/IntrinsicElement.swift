public 
protocol IntrinsicElement<Culture, Offset>:Identifiable
{
    associatedtype Offset:UnsignedInteger where Offset.Stride == Int
    associatedtype Culture:Hashable 
}