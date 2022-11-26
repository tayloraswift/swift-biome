import BSONSchema

extension Mongo.Collation
{
    @frozen public 
    enum Strength:Int32, Sendable 
    {
        /// Primary level of comparison. Collation performs comparisons of the base 
        /// characters only, ignoring other differences such as diacritics and case.
        case primary = 1

        /// Secondary level of comparison. Collation performs comparisons up to 
        /// secondary differences, such as diacritics. That is, collation performs 
        /// comparisons of base characters (primary differences) and diacritics 
        /// (secondary differences). Differences between base characters takes 
        /// precedence over secondary differences.
        case secondary = 2

        /// Tertiary level of comparison. Collation performs comparisons up to 
        /// tertiary differences, such as case and letter variants. That is, 
        /// collation performs comparisons of base characters (primary differences), 
        /// diacritics (secondary differences), and case and variants (tertiary differences). 
        /// Differences between base characters takes precedence over secondary differences, 
        /// which takes precedence over tertiary differences.
        ///
        /// This is the default level.
        case tertiary = 3

        /// Quaternary Level. Limited for specific use case to consider punctuation 
        /// when levels 1-3 ignore punctuation or for processing Japanese text.
        case quaternary = 4

        /// Identical Level. Limited for specific use case of tie breaker.
        case identical = 5
    }
}
extension Mongo.Collation.Strength:BSONScheme
{
}
