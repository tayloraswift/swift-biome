import TraceableErrors

extension Error where Self:Equatable
{
    fileprivate
    func equals(_ other:any Error) -> Bool
    {
        (other as? Self).map { $0 == self } ?? false
    }
}
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
        let error:any Error

        @inlinable public
        init(_ error:any Error, in location:Location)
        {
            self.location = location
            self.error = error
        }
    }
}
extension BSON.RecursiveError:Equatable where Location:Equatable
{
    public static
    func == (lhs:Self, rhs:Self) -> Bool
    {
        if  lhs.location == rhs.location,
            let lhs:any Equatable & Error = lhs.error as? any Equatable & Error
        {
            return lhs.equals(rhs.error)
        }
        else
        {
            return false
        }
    }
}
extension BSON.RecursiveError:TraceableError, CustomStringConvertible
    where Location:CustomStringConvertible
{
    /// Returns the string [`"nested decoding error"`]().
    public static 
    var namespace:String 
    {
        "nested decoding error"
    }

    public 
    var context:[String] 
    {
        ["while decoding value for field '\(self.location)'"]
    }
    /// The underlying error that occurred.
    public 
    var next:(any Error)?
    {
        self.error
    }
}
