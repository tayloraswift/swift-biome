import BSONSchema

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
extension Mongo.Collation:BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(locale: try bson["locale"].decode(to: String.self),
            alternate: try bson["alternate"]?.decode(to: Alternate.self) ?? .nonignorable,
            backwards: try bson["backwards"]?.decode(to: Bool.self) ?? false,
            caseFirst: try bson["caseFirst"]?.decode(to: CaseFirst.self),
            caseLevel: try bson["caseLevel"]?.decode(to: Bool.self) ?? false,
            maxVariable: try bson["maxVariable"]?.decode(to: MaxVariable.self),
            normalization: try bson["normalization"]?.decode(to: Bool.self) ?? false,
            numericOrdering: try bson["numericOrdering"]?.decode(to: Bool.self) ?? false,
            strength: try bson["strength"]?.decode(to: Strength.self) ?? .tertiary)
    }
}
extension Mongo.Collation:BSONDocumentEncodable
{
    public
    func encode(to bson:inout BSON.Fields)
    {
        bson["locale"] = self.locale
        bson["strength"] = self.strength != .tertiary ? self.strength : nil
        bson["caseLevel"] = self.caseLevel ? true : nil
        bson["caseFirst"] = self.caseFirst
        bson["numericOrdering"] = self.numericOrdering ? true : nil
        bson["normalization"] = self.normalization ? true : nil
        bson["backwards"] = self.backwards ? true : nil
        bson["alternate"] = self.alternate != .nonignorable ? self.alternate : nil
        bson["maxVariable"] = self.maxVariable
    }
}
