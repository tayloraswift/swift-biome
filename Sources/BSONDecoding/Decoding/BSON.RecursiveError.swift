import TraceableErrors

extension BSON
{
    /// An error occurred while decoding a document field.
    @frozen public
    struct RecursiveError<Location>:Error
    {
        /// The location (key or index) where the error occurred.
        public
        let location:Location
        /// The underlying error that occurred.
        public
        let underlying:any Error

        @inlinable public
        init(_ underlying:any Error, in location:Location)
        {
            self.location = location
            self.underlying = underlying
        }
    }
}
extension BSON.RecursiveError:Equatable where Location:Equatable
{
    public static
    func == (lhs:Self, rhs:Self) -> Bool
    {
        lhs.location == rhs.location &&
        lhs.underlying == rhs.underlying
    }
}
extension BSON.RecursiveError:TraceableError, CustomStringConvertible
    where Location:CustomStringConvertible
{
    public 
    var notes:[String] 
    {
        ["while decoding value for field '\(self.location)'"]
    }
}
