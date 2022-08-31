import Grammar 

@frozen public 
struct SemanticVersion:Sendable 
{
    public 
    var major:Int 
    public 
    var minor:Int 
    public 
    var patch:Int 

    @inlinable public 
    init(_ major:Int, _ minor:Int, _ patch:Int)
    {
        self.major = major 
        self.minor = minor 
        self.patch = patch 
    }
    @inlinable public 
    init(parsing string:some StringProtocol) throws 
    {
        self = try Rule<String.Index>.parse(string.unicodeScalars)
    }
}
extension SemanticVersion:Hashable, Comparable 
{
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
extension SemanticVersion:CustomStringConvertible
{
    @inlinable public 
    var description:String
    {
        "\(self.major).\(self.minor).\(self.patch)"
    }
}
extension SemanticVersion 
{
    public 
    enum Rule<Location>:ParsingRule
    {
        public 
        typealias Terminal = Unicode.Scalar
        
        public 
        typealias Integer = Pattern.UnsignedInteger<
            UnicodeDigit<Location, Unicode.Scalar, Int>.DecimalScalar>
        public 
        typealias Period = UnicodeEncoding<Location, Unicode.Scalar>.Period

        @inlinable public static 
        func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
            throws -> SemanticVersion
            where Source:Collection<Unicode.Scalar>, Source.Index == Location
        {
            let major:Int = try input.parse(as: Integer.self)
                            try input.parse(as: Period.self)
            let minor:Int = try input.parse(as: Integer.self)
                            try input.parse(as: Period.self)
            let patch:Int = try input.parse(as: Integer.self)
            return .init(major, minor, patch)
        }
    }
}