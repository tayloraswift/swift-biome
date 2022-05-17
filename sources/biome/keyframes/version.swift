import JSON

public 
struct Version:CustomStringConvertible, Sendable
{
    typealias Date  = (year:Int, month:Int, day:Int, letter:Unicode.Scalar)
    typealias Tag   = (major:Int, (minor:Int, (patch:Int, edition:Int?)?)?)
    
    enum Format 
    {
        case date(Date)
        case tag(Tag)
        case latest
    }
    
    private 
    var bitPattern:UInt64
    
    @available(*, unavailable)
    static 
    func == (lhs:Self, rhs:Self) -> Bool 
    {
        false
    }
    static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.bitPattern < rhs.bitPattern 
    }
    
    var format:Format 
    {
        guard self.bitPattern & 0x8000_0000_0000_0000 == 0 
        else 
        {
            let year:Int    = .init(self.bitPattern >> 48 & 0x0fff),
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
                return .tag((major, nil))
            }
            guard let patch:Int = try $0.pop("patch", as: Int.self)
            else 
            {
                return .tag((major, (minor, nil)))
            }
            return .tag((major, (minor, (patch, nil))))
        }
    }
}
