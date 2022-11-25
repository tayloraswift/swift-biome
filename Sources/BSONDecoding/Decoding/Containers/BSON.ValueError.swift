extension BSON
{
    /// A decoder successfully to cast a variant to an expected value type,
    /// but it was not a valid case of the expected destination type.
    @frozen public 
    struct ValueError<Value, Cases>:Error
    {
        public
        let value:Value

        @inlinable public
        init(invalid value:Value)
        {
            self.value = value
        }
    }
}
extension BSON.ValueError:Equatable where Value:Equatable
{
}
extension BSON.ValueError:CustomStringConvertible
{
    public
    var description:String
    {
        "value '\(self.value)' does not encode a valid instance of type '\(Cases.self)'"
    }
}
