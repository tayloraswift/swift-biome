import BSON

extension Mongo
{
    @frozen public
    struct Collation:Sendable
    {
        public
        let locale:String
        public
        let strength:Strength
        public
        let alternate:Alternate
        public
        let backwards:Bool
        public
        let caseFirst:CaseFirst?
        public
        let caseLevel:Bool
        public
        let normalization:Bool
        public
        let numericOrdering:Bool

        @inlinable public
        init(locale:String = "simple",
            strength:Strength = .tertiary,
            alternate:Alternate = .nonIgnorable,
            backwards:Bool = false,
            caseFirst:CaseFirst? = nil,
            caseLevel:Bool = false,
            normalization:Bool = false,
            numericOrdering:Bool = false)
        {
            self.locale = locale
            self.strength = strength
            self.alternate = alternate
            self.backwards = backwards
            self.caseFirst = caseFirst
            self.caseLevel = caseLevel
            self.normalization = normalization
            self.numericOrdering = numericOrdering
        }
    }
}
extension Mongo.Collation
{
    var document:BSON.Document<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> =
        [
            "locale": .string(self.locale),
            "strength": self.strength != .tertiary ? .int32(self.strength.rawValue) : nil,
            "caseLevel": self.caseLevel ? true : nil,
            "caseFirst": (self.caseFirst?.rawValue)
                .map(BSON.Value<[UInt8]>.string(_:)),
            "numericOrdering": self.numericOrdering ? true : nil,
            "normalization": self.normalization ? true : nil,
            "backwards": self.backwards ? true : nil,
        ]
        if case .shifted(let maxVariable) = self.alternate
        {
            fields.add(key: "alternate", value: .string("shifted"))

            if let maxVariable:Alternate.MaxVariable
            {
                fields.add(key: "maxVariable", value: .string(maxVariable.rawValue))
            }
        }
        return .init(fields)
    }
    var bson:BSON.Value<[UInt8]>
    {
        .document(self.document)
    }

    @frozen public 
    enum Alternate:Sendable 
    {
        case nonIgnorable
        case shifted(MaxVariable?)

        @frozen public 
        enum MaxVariable:String, Sendable 
        {
            case punct
            case space
        }
    }
    @frozen public 
    enum CaseFirst:String, Sendable 
    {
        case lower
        case upper
    }
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
