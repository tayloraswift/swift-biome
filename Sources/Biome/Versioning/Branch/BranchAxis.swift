protocol BranchAxis<Key, Element>:PluralAxis
{
    subscript<Value>(field:Field<Value>) -> OriginalHead<Value>?
    {
        get
    }
    subscript<Value>(field:Field<Value>, 
        since revision:Version.Revision) -> OriginalHead<Value>?
    {
        get set
    }
}