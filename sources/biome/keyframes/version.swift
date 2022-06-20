struct Version:Hashable, Sendable
{
    var bitPattern:UInt64
    
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
    
    // we have `<` and `<=`, yet `Self` is not ``Comparable``...
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
    
    var semantic:(major:UInt16, minor:UInt16, patch:UInt16, edition:UInt16)? 
    {
        self.bitPattern & 0x8000_0000_0000_0000 != 0 ? 
            (self.x & 0x7fff, self.y, self.z, self.w) : nil
    }
    var precise:MaskedVersion 
    {
        self.semantic.map(MaskedVersion.semantic(_:)) ??
            .date(year: self.x, month: self.y, day: self.z, letter: .init(self.w))
    }
    
    static 
    let max:Self = .init(bitPattern: 0xffff_ffff_ffff_ffff)
    
    private 
    init(bitPattern:UInt64)
    {
        self.bitPattern = bitPattern
    }
    init(_ masked:MaskedVersion?)
    {
        switch masked 
        {
        case nil: 
            self.init()
        case .major(let major)?:
            self.init(major: major)
        case .minor(let major, let minor)?:
            self.init(major: major, minor: minor)
        case .patch(let major, let minor, let patch)?:
            self.init(major: major, minor: minor, patch: patch)
        case .edition(let major, let minor, let patch, let edition)?:
            self.init(major: major, minor: minor, patch: patch, edition: edition)
        case .date(year: let year, month: let month, day: let day, letter: let letter)?:
            self.init(year: year, month: month, day: day, letter: letter)
        }
    }
    init(major:UInt16 = 0, minor:UInt16 = 0, patch:UInt16 = 0, edition:UInt16 = 0)
    {
        precondition(major < 0x8000)
        self.bitPattern = 0x8000_0000_0000_0000 as UInt64 | 
            UInt64.init(major) << 48 as UInt64 |
            UInt64.init(minor) << 32 as UInt64 |
            UInt64.init(patch) << 16 as UInt64 |
            UInt64.init(edition)
    }
    init(year:UInt16, month:UInt16, day:UInt16, letter:UInt8) 
    {
        precondition(year < 0x8000)
        precondition( 0  ...  12 ~= month)
        precondition( 0  ...  31 ~= day)
        precondition("a" ... "z" ~= Unicode.Scalar.init(letter))
        self.bitPattern =
            UInt64.init(year)   << 48 as UInt64 |
            UInt64.init(month)  << 32 as UInt64 |
            UInt64.init(day)    << 16 as UInt64 |
            UInt64.init(letter)
    } 
}
