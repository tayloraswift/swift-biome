import BSONSchema

extension Mongo.Collation
{
    @frozen public 
    enum Alternate:String, Sendable
    {
        /// Whitespace and punctuation are considered base characters.
        ///
        /// This is called [`non-ignorable`] (with a hyphen) in the server’s
        /// scheme, and is therefore not camel-cased.
        case nonignorable = "non-ignorable"
        /// Whitespace and punctuation are not considered base characters
        /// and are only distinguished at strength levels greater than 3.
        case shifted
    }
}
extension Mongo.Collation.Alternate:BSONScheme
{
}
