import Versions
import JSON

@frozen public 
struct Availability:Equatable, Sendable
{
    public
    var swift:SwiftAvailability?
    //let tools:SwiftAvailability?
    public
    var general:UnversionedAvailability?
    public
    var platforms:[Platform: VersionedAvailability]
    
    @inlinable public
    var isEmpty:Bool 
    {
        if  case nil = self.swift, 
            case nil = self.general, 
            self.platforms.isEmpty 
        {
            return true 
        }
        else 
        {
            return false
        }
    }
    @inlinable public
    var isUsable:Bool 
    {
        if  let generally:UnversionedAvailability = self.general, 
                generally.unavailable || generally.deprecated
        {
            return false 
        }
        if  let currently:SwiftAvailability = self.swift, 
               !currently.isUsable
        {
            return false 
        }
        else 
        {
            return true
        }
    }
    @inlinable public
    init(swift:SwiftAvailability? = nil, 
        general:UnversionedAvailability? = nil, 
        platforms:[Platform: VersionedAvailability] = [:])
    {
        self.swift = swift
        self.general = general
        self.platforms = platforms
    }
}
extension Availability 
{
    init(lowering json:[JSON]) throws 
    {
        try self.init(try json.map 
        {
            try $0.lint
            {
                let deprecated:VersionedAvailability.Deprecation? 
                if let flag:Bool = try $0.pop("isUnconditionallyDeprecated", as: Bool.self)
                {
                    deprecated = flag ? .always : nil
                }
                else if let version:MaskedVersion? = 
                    try $0.pop("deprecated", MaskedVersion.init(exactly:))
                {
                    deprecated = version.map(VersionedAvailability.Deprecation.since(_:))
                }
                else 
                {
                    deprecated = nil 
                }
                // possible to be both unconditionally unavailable and unconditionally deprecated
                let availability:VersionedAvailability = .init(
                    unavailable: try $0.pop("isUnconditionallyUnavailable", as: Bool.self) ?? false,
                    deprecated: deprecated,
                    introduced: try $0.pop("introduced", MaskedVersion.init(exactly:)) ?? nil,
                    obsoleted: try $0.pop("obsoleted", MaskedVersion.init(exactly:)) ?? nil, 
                    renamed: try $0.pop("renamed", as: String?.self),
                    message: try $0.pop("message", as: String?.self))
                let domain:Domain = try $0.remove("domain") { try $0.as(cases: Domain.self) }
                return (key: domain, value: availability)
            }
        })
    }
    private 
    init(_ items:[(key:Domain, value:VersionedAvailability)]) throws
    {
        self.init()
        for (key, value):(Domain, VersionedAvailability) in items
        {
            switch key 
            {
            case .general:
                if case nil = self.general
                {
                    self.general = .init(value)
                }
                else 
                {
                    throw SymbolGraphDecodingError.duplicateAvailabilityDomain(key)
                }
            
            case .swift:
                if case nil = self.swift 
                {
                    self.swift = .init(value)
                }
                else 
                {
                    throw SymbolGraphDecodingError.duplicateAvailabilityDomain(key)
                }
            
            case .tools:
                fatalError("unimplemented (yet)")
            
            case .platform(let platform):
                guard case nil = self.platforms.updateValue(value, forKey: platform)
                else 
                {
                    throw SymbolGraphDecodingError.duplicateAvailabilityDomain(key)
                }
            }
        }
    }
}
