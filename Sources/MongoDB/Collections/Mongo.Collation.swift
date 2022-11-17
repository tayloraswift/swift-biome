import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct Collation:Sendable
    {
        public
        let locale:String

        public
        let alternate:Alternate
        public
        let backwards:Bool
        public
        let caseFirst:CaseFirst?
        public
        let caseLevel:Bool
        /// Determines up to which characters are considered ignorable when
        /// ``alternate`` is ``Alternate/.shifted``.
        /// Has no effect ``Alternate/.nonignorable``.
        ///
        /// This is modeled as a separate property from ``alternate`` because
        /// it depends the value of ``alternate``, rather than its presence.
        public
        let maxVariable:MaxVariable?
        public
        let normalization:Bool
        public
        let numericOrdering:Bool
        public
        let strength:Strength

        @inlinable public
        init(locale:String,
            alternate:Alternate = .nonignorable,
            backwards:Bool = false,
            caseFirst:CaseFirst? = nil,
            caseLevel:Bool = false,
            maxVariable:MaxVariable? = nil,
            normalization:Bool = false,
            numericOrdering:Bool = false,
            strength:Strength = .tertiary)
        {
            self.locale = locale
            self.alternate = alternate
            self.backwards = backwards
            self.caseFirst = caseFirst
            self.caseLevel = caseLevel
            self.maxVariable = maxVariable
            self.normalization = normalization
            self.numericOrdering = numericOrdering
            self.strength = strength
        }
    }
}
extension Mongo.Collation:MongoScheme, MongoRepresentable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(locale: try bson["locale"].decode(to: String.self),
            alternate: try bson["alternate"]?.decode(cases: Alternate.self) ?? .nonignorable,
            backwards: try bson["backwards"]?.decode(to: Bool.self) ?? false,
            caseFirst: try bson["caseFirst"]?.decode(cases: CaseFirst.self),
            caseLevel: try bson["caseLevel"]?.decode(to: Bool.self) ?? false,
            maxVariable: try bson["maxVariable"]?.decode(cases: MaxVariable.self),
            normalization: try bson["normalization"]?.decode(to: Bool.self) ?? false,
            numericOrdering: try bson["numericOrdering"]?.decode(to: Bool.self) ?? false,
            strength: try bson["strength"]?.decode(cases: Strength.self) ?? .tertiary)
    }
    public
    var bson:BSON.Document<[UInt8]>
    {
        let fields:BSON.Fields<[UInt8]> =
        [
            "locale": .string(self.locale),
            "strength": self.strength != .tertiary ?
                .int32(self.strength.rawValue) : nil,
            "caseLevel": self.caseLevel ? true : nil,
            "caseFirst": (self.caseFirst?.rawValue)
                .map(BSON.Value<[UInt8]>.string(_:)),
            "numericOrdering": self.numericOrdering ? true : nil,
            "normalization": self.normalization ? true : nil,
            "backwards": self.backwards ? true : nil,
            "alternate": self.alternate != .nonignorable ?
                .string(self.alternate.rawValue) : nil,
            "maxVariable": .string(self.maxVariable?.rawValue),
        ]
        return .init(fields)
    }
}
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
    @frozen public 
    enum MaxVariable:String, Sendable 
    {
        /// Both whitespace and punctuation are ignorable and not considered
        /// base characters.
        case punct
        /// Whitespace is ignorable and not considered to be base characters.
        case space
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
