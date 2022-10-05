protocol PluralAxis<Key, Element>
{
    associatedtype Key
    associatedtype Element:BranchElement

    typealias Field<Value> = FieldAccessor<Element, Key, Value>
}