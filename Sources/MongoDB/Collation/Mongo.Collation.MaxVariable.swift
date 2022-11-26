import BSONSchema

extension Mongo.Collation
{
    @frozen public 
    enum MaxVariable:String, Sendable 
    {
        /// Both whitespace and punctuation are ignorable and not considered
        /// base characters.
        case punct
        /// Whitespace is ignorable and not considered to be base characters.
        case space
    }
}
extension Mongo.Collation.MaxVariable:BSONScheme
{
}
