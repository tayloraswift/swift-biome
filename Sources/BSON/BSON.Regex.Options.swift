extension BSON.Regex
{
    public
    enum OptionError:Error
    {
        case invalid(Unicode.Scalar)
    }

    @frozen public 
    enum Option:UInt8, Sendable
    {
        case i = 0b000001
        case l = 0b000010
        case m = 0b000100
        case s = 0b001000
        case u = 0b010000
        case x = 0b100000
    }
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
}
extension BSON.Regex.Options
{
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
