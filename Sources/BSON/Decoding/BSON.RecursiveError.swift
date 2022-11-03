extension BSON
{
    /// An error occurred while decoding a document field.
    public
    enum RecursiveError:Error
    {
        /// An error occurred while decoding a tuple element at a particular index.
        case tuple      (any Error, at:Int)
        /// An error occurred while decoding a document field for a particular key.
        case document   (any Error, in:String)
    }
}
extension BSON.RecursiveError
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
        switch self 
        {
        case .tuple(_, at: let index): 
            return ["while decoding tuple element \(index)"]
        case .document(_, in: let key): 
            return ["while decoding document field '\(key)'"]
        }
    }
    /// The underlying error that occurred.
    public 
    var next:Error?
    {
        switch self 
        {
        case    .tuple      (let error, at: _), 
                .document   (let error, in: _): 
            return error
        }
    }
}
