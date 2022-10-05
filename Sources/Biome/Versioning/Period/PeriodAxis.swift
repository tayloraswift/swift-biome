protocol PeriodAxis<Key, Element>:PluralAxis
{
    subscript<Value>(field:Field<Value>) -> PeriodHead<Value>
    {
        get
    }
}
