import JSON
// FIXME: this is full of security vulnerabilities!
@frozen public 
struct Version:Hashable, CustomStringConvertible, Sendable
{
    typealias Date  = (year:Int, month:Int, day:Int, letter:Unicode.Scalar)
    typealias Tag   = (major:Int, (minor:Int, (patch:Int, edition:Int?)?)?)
    
    enum Format 
    {
        case date(Date)
        case tag(Tag)
        case latest
    }
    
    public 
    var bitPattern:UInt64
    
    @usableFromInline
    init(bitPattern:UInt64)
    {
        self.bitPattern = bitPattern
    }
    
    static 
    func <= (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.bitPattern <= rhs.bitPattern 
    }
    static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.bitPattern < rhs.bitPattern 
    }
    
    public static 
    let latest:Self = .init(bitPattern: 0xffff_ffff_ffff_ffff)
    
    @inlinable public static 
    func tag(_ major:Int, _ minor:(Int, (patch:Int, edition:Int?)?)?) -> Self 
    {
        var version:Self = .latest 
        precondition(major < 0xffff)
        version.bitPattern &= UInt64.init(major) << 48 | 0x0000_ffff_ffff_ffff
        guard case let (minor, patch)? = minor 
        else 
        {
            return version
        }
        precondition(minor < 0xffff)
        version.bitPattern &= UInt64.init(minor) << 32 | 0xffff_0000_ffff_ffff
        guard case let (patch, edition)? = patch 
        else 
        {
            return version
        }
        precondition(patch < 0xffff)
        version.bitPattern &= UInt64.init(patch) << 16 | 0xffff_ffff_0000_ffff
        guard let edition:Int = edition 
        else 
        {
            return version
        }
        precondition(edition < 0xffff)
        version.bitPattern &= UInt64.init(edition)     | 0xffff_ffff_ffff_0000
        return version
    }
    @inlinable public static  
    func date(year:Int, month:Int, day:Int, letter:Unicode.Scalar) -> Self 
    {
        precondition(year < 0x7fff)
        precondition( 0  ...  12 ~= month)
        precondition( 0  ...  31 ~= day)
        precondition("a" ... "z" ~= letter)
        return .init(bitPattern: 0x8000_0000_0000_0000 as UInt64 |
            UInt64.init(year)   << 48 as UInt64 |
            UInt64.init(month)  << 32 as UInt64 |
            UInt64.init(day)    << 16 as UInt64 |
            UInt64.init(letter.value) as UInt64 )
    } 
    
    var format:Format 
    {
        guard self.bitPattern & 0x8000_0000_0000_0000 == 0 
        else 
        {
            let year:Int    = .init(self.bitPattern >> 48 & 0x7fff),
                month:Int   = .init(self.bitPattern >> 32 & 0xffff),
                day:Int     = .init(self.bitPattern >> 16 & 0xffff),
                letter:UInt8 = .init(truncatingIfNeeded: self.bitPattern)
            return .date((year, month, day, Unicode.Scalar.init(letter)))
        }
        let major:Int   = .init(self.bitPattern >> 48),
            minor:Int   = .init(self.bitPattern >> 32 & 0xffff),
            patch:Int   = .init(self.bitPattern >> 16 & 0xffff),
            edition:Int = .init(self.bitPattern       & 0xffff)
        guard major != 0xffff 
        else 
        {
            return .latest
        }
        guard minor != 0xffff 
        else 
        {
            return .tag((major, nil))
        }
        guard patch != 0xffff 
        else 
        {
            return .tag((major, (minor, nil)))
        }
        guard edition != 0xffff 
        else 
        {
            return .tag((major, (minor, (patch, nil))))
        }
        return .tag((major, (minor, (patch, edition))))
    }
    
    public 
    var description:String 
    {
        switch self.format
        {
        case .date((let year, let month, let day, letter: let letter)):
            // not zero-padded, and probably unsuitable for generating 
            // links to toolchains.
            return "\(year)-\(month)-\(day)-\(letter)"
        case .latest:
            return "latest"
        case .tag((let major, nil)):
            return "\(major)"
        case .tag((let major, (let minor, nil)?)):
            return "\(major).\(minor)"
        case .tag((let major, (let minor, (let patch, nil)?)?)):
            return "\(major).\(minor).\(patch)"
        case .tag((let major, (let minor, (let patch, let edition?)?)?)):
            return "\(major).\(minor).\(patch).\(edition)"
        }
    }
    
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let major:Int = try $0.remove("major", as: Int.self)
            guard let minor:Int = try $0.pop("minor", as: Int.self)
            else 
            {
                return .tag(major, nil)
            }
            guard let patch:Int = try $0.pop("patch", as: Int.self)
            else 
            {
                return .tag(major, (minor, nil))
            }
            return .tag(major, (minor, (patch, nil)))
        }
    }
}
extension Version 
{
    struct Rule<Location>:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
extension Version.Rule 
{
    private 
    typealias Integer = Grammar.UnsignedIntegerLiteral<
                        Grammar.DecimalDigitScalar<Location, Int>>
    
    private 
    enum ToolchainOrdinal:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Unicode.Scalar
        static 
        func parse(terminal:Terminal) -> Unicode.Scalar?
        {
            switch terminal 
            {
            case "a" ... "z":   return terminal 
            //case "A" ... "Z":   return terminal.lowercased()
            default:            return nil
            }
        }
    }
    
    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
        throws -> Version
        where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
    {
        let first:Int = try input.parse(as: Integer.self)
        guard case nil = input.parse(as: Encoding.Hyphen?.self)
        else 
        {
            // parse a date 
            let month:Int = try input.parse(as: Integer.self)
            try input.parse(as: Encoding.Hyphen.self)
            let day:Int = try input.parse(as: Integer.self)
            try input.parse(as: Encoding.Hyphen.self)
            let letter:Unicode.Scalar = try input.parse(as: ToolchainOrdinal.self)
            return .date(year: first, month: month, day: day, letter: letter)
        }
        // parse a x.y.z.w semantic version. the w component is 
        // a documentation version, which is a sub-patch increment
        guard case let (_, minor)? = 
            try? input.parse(as: (Encoding.Period, Integer).self)
        else 
        {
            return .tag(first, nil)
        }
        guard case let (_, patch)? = 
            try? input.parse(as: (Encoding.Period, Integer).self)
        else 
        {
            return .tag(first, (minor, nil))
        }
        guard case let (_, edition)? = 
            try? input.parse(as: (Encoding.Period, Integer).self)
        else 
        {
            return .tag(first, (minor, (patch, nil)))
        }
        return .tag(first, (minor, (patch, edition)))
    }
}
