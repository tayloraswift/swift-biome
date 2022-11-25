import BSON

extension BSON
{
    /// A decoder failed to cast a variant to an expected value type.
    @frozen public 
    struct TypecastError<Value>:Equatable, Error
    {
        public
        let variant:BSON

        @inlinable public
        init(invalid variant:BSON)
        {
            self.variant = variant
        }
    }
}
extension BSON.TypecastError:CustomStringConvertible
{
    public
    var description:String 
    {
        "cannot cast variant of type '\(self.variant)' to type '\(Value.self)'"
    }
}
