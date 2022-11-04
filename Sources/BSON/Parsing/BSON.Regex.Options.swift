extension BSON.Regex
{
    /// A MongoDB regex matching options string contained an invalid unicode scalar.
    public
    enum OptionError:Equatable, Error
    {
        case invalid(Unicode.Scalar)
    }
}
extension BSON.Regex.OptionError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .invalid(let codepoint):
            return "invalid regex option '\(codepoint)'"
        }
    }
}
extension BSON.Regex
{
    /// A MongoDB regex matching option.
    @frozen public 
    enum Option:UInt8, CaseIterable, Hashable, Sendable
    {
        /// Enables case-insensitive matching.
        case i = 0b000001
        /// Enables localization for `\w`, `\W`, etc.
        case l = 0b000010
        /// Enables multiline matching.
        case m = 0b000100
        /// Enables dotall mode. ([`'.'`]() matches everything.)
        case s = 0b001000
        /// Enables unicode awareness for `\w`, `\W`, etc.
        case u = 0b010000
        /// Enables verbose mode.
        case x = 0b100000
    }
    /// A set of MongoDB regex matching options.
    @frozen public 
    struct Options:OptionSet, Sendable
    {
        public
        let rawValue:UInt8

        @inlinable public 
        init(rawValue:UInt8)
        {
            self.rawValue = rawValue
        }

        public static let i:Self = .init(rawValue: Option.i.rawValue)
        public static let l:Self = .init(rawValue: Option.l.rawValue)
        public static let m:Self = .init(rawValue: Option.m.rawValue)
        public static let s:Self = .init(rawValue: Option.s.rawValue)
        public static let u:Self = .init(rawValue: Option.u.rawValue)
        public static let x:Self = .init(rawValue: Option.x.rawValue)
    }
}
extension BSON.Regex.Option
{
    @inlinable public
    init?(_ scalar:Unicode.Scalar)
    {
        switch scalar
        {
        case "i": self = .i
        case "l": self = .l
        case "m": self = .m
        case "s": self = .s
        case "u": self = .u
        case "x": self = .x
        default:  return nil
        }
    }
    @inlinable public
    var scalar:Unicode.Scalar
    {
        switch self
        {
        case .i: return "i"
        case .l: return "l"
        case .m: return "m"
        case .s: return "s"
        case .u: return "u"
        case .x: return "x"
        }
    }
    @inlinable public
    var character:Character
    {
        .init(self.scalar)
    }
}
extension BSON.Regex.Options
{
    /// Parses an option set from a MongoDB regex matching options string.
    @inlinable public
    init(parsing string:some StringProtocol) throws
    {
        var rawValue:UInt8 = 0
        for scalar:Unicode.Scalar in string.unicodeScalars
        {
            if  let option:BSON.Regex.Option = .init(scalar)
            {
                rawValue |= option.rawValue
            }
            else
            {
                throw BSON.Regex.OptionError.invalid(scalar)
            }
        }
        self.init(rawValue: rawValue)
    }
}

extension BSON.Regex.Options
{
    /// The size of this option set, when encoded as a option string, including
    /// its trailing null byte.
    @inlinable public
    var size:Int
    {
        self.rawValue.nonzeroBitCount + 1
    }
}
extension BSON.Regex.Options:CustomStringConvertible
{
    @inlinable public
    func contains(option:BSON.Regex.Option) -> Bool
    {
        self.rawValue & option.rawValue != 0
    }
    /// This option set, encoded in alphabetical order as a option string.
    @inlinable public
    var description:String
    {
        .init(BSON.Regex.Option.allCases.lazy.compactMap
        {
            self.contains(option: $0) ? $0.character : nil
        })
    }
}