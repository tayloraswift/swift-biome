extension BSON
{
    /// An overflow occurred while converting an integer value to a desired type.
    @frozen public
    enum IntegerOverflowError:Error 
    {
        case int32  (Int32,  overflows:any FixedWidthInteger.Type)
        case int64  (Int64,  overflows:any FixedWidthInteger.Type)
        case uint64 (UInt64, overflows:any FixedWidthInteger.Type)
    }
}
extension BSON.IntegerOverflowError:CustomStringConvertible
{
    public
    var description:String 
    {
        switch self
        {
        case .int32 (let value, overflows: let type):
            return "value '\(value)' of type 'int32' overflows decoded type '\(type)'"
        case .int64 (let value, overflows: let type):
            return "value '\(value)' of type 'int64' overflows decoded type '\(type)'"
        case .uint64(let value, overflows: let type):
            return "value '\(value)' of type 'uint64' overflows decoded type '\(type)'"
        }
    }
}
