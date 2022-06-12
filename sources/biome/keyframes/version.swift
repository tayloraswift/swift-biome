import JSON
// FIXME: this is full of security vulnerabilities!
@frozen public 
struct Version:Hashable, CustomStringConvertible, Sendable
{    
    public 
    var bitPattern:UInt64
    
    var isSemantic:Bool 
    {
        self.bitPattern & 0x8000_0000_0000_0000 != 0 
    }
    
    private static 
    let x:UInt64 = 0x0000_ffff_ffff_ffff, 
        y:UInt64 = 0xffff_0000_ffff_ffff,
        z:UInt64 = 0xffff_ffff_0000_ffff,
        w:UInt64 = 0xffff_ffff_ffff_0000
    
    private 
    var x:UInt16 
    {
        get     { .init(                     self.bitPattern                  >> 48) }
        set(x)  { self.bitPattern = Self.x & self.bitPattern | UInt64.init(x) << 48  }
    }
    private 
    var y:UInt16 
    {
        get     { .init(truncatingIfNeeded:  self.bitPattern                  >> 32) }
        set(y)  { self.bitPattern = Self.y & self.bitPattern | UInt64.init(y) << 32  }
    }
    private 
    var z:UInt16 
    {
        get     { .init(truncatingIfNeeded:  self.bitPattern                  >> 16) }
        set(z)  { self.bitPattern = Self.z & self.bitPattern | UInt64.init(z) << 16  }
    }
    private 
    var w:UInt16 
    {
        get     { .init(truncatingIfNeeded:  self.bitPattern) }
        set(w)  { self.bitPattern = Self.w & self.bitPattern | UInt64.init(w) }
    }
    
    private 
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
    
    var floored:Self 
    {
        guard self.isSemantic 
        else 
        {
            return self 
        }
        
        var version:Self = self 
        if  version.x == .max 
        {
            version.x = 0x8000
            version.y = 0
            version.z = 0
            version.w = 0
            return version
        }
        if  version.y == .max 
        {
            version.y = 0
            version.z = 0
            version.w = 0
            return version
        }
        if  version.z == .max 
        {
            version.z = 0
            version.w = 0
            return version
        }
        if  version.w == .max 
        {
            version.w = 0
            return version
        }
        else 
        {
            return version
        }
    }
    var editionless:Self 
    {
        .init(bitPattern: self.bitPattern | 0x0000_0000_0000_ffff)
    }
    var patchless:Self 
    {
        .init(bitPattern: self.bitPattern | 0x0000_0000_ffff_ffff)
    }
    var minorless:Self 
    {
        .init(bitPattern: self.bitPattern | 0x0000_ffff_ffff_ffff)
    }
    
    public static 
    let latest:Self = .init(bitPattern: 0xffff_ffff_ffff_ffff)
    
    public static 
    func tag(_ major:UInt16, _ minor:(UInt16, (patch:UInt16, edition:UInt16?)?)?) -> Self 
    {
        precondition(major < 0x8000)
        
        var version:Self = .latest 
        version.x = major | 0x8000
        guard case let (minor, patch)? = minor 
        else 
        {
            return version
        }
        version.y = minor
        guard case let (patch, edition)? = patch 
        else 
        {
            return version
        }
        version.z = patch
        guard let edition:UInt16 = edition 
        else 
        {
            return version
        }
        version.w = edition
        
        return version
    }
    
    public static  
    func date(year:UInt16, month:UInt16, day:UInt16, letter:Unicode.Scalar) -> Self 
    {
        precondition(year < 0x8000)
        precondition( 0  ...  12 ~= month)
        precondition( 0  ...  31 ~= day)
        precondition("a" ... "z" ~= letter)
        return .init(bitPattern: 
            UInt64.init(year)   << 48 as UInt64 |
            UInt64.init(month)  << 32 as UInt64 |
            UInt64.init(day)    << 16 as UInt64 |
            UInt64.init(letter.value) as UInt64 )
    } 
    
    public 
    var description:String 
    {
        guard self.isSemantic
        else 
        {
            // not zero-padded, and probably unsuitable for generating 
            // links to toolchains.
            let letter:Unicode.Scalar = .init(UInt8.init(truncatingIfNeeded: self.w))
            return "\(self.x)-\(self.y)-\(self.z)-\(letter)"
        }
        
        let major:UInt16    = self.x & 0x7fff,
            minor:UInt16    = self.y,
            patch:UInt16    = self.z,
            edition:UInt16  = self.w
        
        guard major != 0x7fff 
        else 
        {
            return "latest"
        }
        guard minor != 0xffff 
        else 
        {
            return "\(major)"
        }
        guard patch != 0xffff 
        else 
        {
            return "\(major).\(minor)"
        }
        guard edition != 0xffff 
        else 
        {
            return "\(major).\(minor).\(patch)"
        }
        return "\(major).\(minor).\(patch).\(edition)"
    }
    
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let major:UInt16 = try $0.remove("major", as: UInt16.self)
            guard let minor:UInt16 = try $0.pop("minor", as: UInt16.self)
            else 
            {
                return .tag(major, nil)
            }
            guard let patch:UInt16 = try $0.pop("patch", as: UInt16.self)
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
                        Grammar.DecimalDigitScalar<Location, UInt16>>
    
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
        let first:UInt16 = try input.parse(as: Integer.self)
        guard case nil = input.parse(as: Encoding.Hyphen?.self)
        else 
        {
            // parse a date 
            let month:UInt16 = try input.parse(as: Integer.self)
            try input.parse(as: Encoding.Hyphen.self)
            let day:UInt16 = try input.parse(as: Integer.self)
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
