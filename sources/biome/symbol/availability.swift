enum Platform:String, Hashable, Sendable 
{
    case iOS 
    case macOS
    case macCatalyst
    case tvOS
    case watchOS
    case windows    = "Windows"
    case openBSD    = "OpenBSD"
    
    case iOSApplicationExtension
    case macOSApplicationExtension
    case macCatalystApplicationExtension
    case tvOSApplicationExtension
    case watchOSApplicationExtension
    
    /* static 
    var platforms:[Self]
    {
        [
            Self.iOS ,
            Self.macOS,
            Self.macCatalyst,
            Self.tvOS,
            Self.watchOS,
            Self.windows,
            Self.openBSD,
        ]
    } */
}

enum AvailabilityError:Error 
{
    case duplicate(domain:AvailabilityDomain)
}

struct Availability:Sendable
{
    var swift:SwiftAvailability?
    //let tools:SwiftAvailability?
    var general:UnversionedAvailability?
    var platforms:[Platform: VersionedAvailability]
    
    init()
    {
        self.swift = nil 
        self.general = nil 
        self.platforms = [:]
    }
    init(_ items:[(key:AvailabilityDomain, value:VersionedAvailability)]) throws
    {
        self.init()
        for (key, value):(AvailabilityDomain, VersionedAvailability) in items
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
                    throw AvailabilityError.duplicate(domain: key)
                }
            
            case .swift:
                if case nil = self.swift 
                {
                    self.swift = .init(value)
                }
                else 
                {
                    throw AvailabilityError.duplicate(domain: key)
                }
            
            case .tools:
                fatalError("unimplemented (yet)")
            
            case .platform(let platform):
                guard case nil = self.platforms.updateValue(value, forKey: platform)
                else 
                {
                    throw AvailabilityError.duplicate(domain: key)
                }
            }
        }
    }
}
struct SwiftAvailability:Sendable
{
    // unconditionals not allowed 
    var deprecated:Version?
    var introduced:Version?
    var obsoleted:Version?
    var renamed:String?
    var message:String?
    
    init(_ versioned:VersionedAvailability)
    {
        self.deprecated = versioned.deprecated ?? nil
        self.introduced = versioned.introduced
        self.obsoleted = versioned.obsoleted
        self.renamed = versioned.renamed
        self.message = versioned.message
    }
}
struct UnversionedAvailability:Sendable
{
    var unavailable:Bool 
    var deprecated:Bool 
    var renamed:String?
    var message:String?
    
    init(_ versioned:VersionedAvailability)
    {
        self.unavailable = versioned.unavailable 
        self.deprecated = versioned.isGenerallyDeprecated 
        self.renamed = versioned.renamed 
        self.message = versioned.message
    }
}
struct VersionedAvailability:Sendable 
{
    var unavailable:Bool 
    // .some(nil) represents unconditional deprecation
    var deprecated:Version??
    var introduced:Version?
    var obsoleted:Version?
    var renamed:String?
    var message:String?
    
    var isGenerallyDeprecated:Bool 
    {
        if case .some(nil) = self.deprecated 
        {
            return true 
        }
        else 
        {
            return false 
        }
    }
}

// https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/AvailabilityMixin.cpp
enum AvailabilityDomain:RawRepresentable
{
    case general
    case swift
    case tools
    case platform(Platform)
    
    init?(rawValue:String)
    {
        switch rawValue 
        {
        case "*":       self = .general
        case "Swift":   self = .swift
        case "SwiftPM": self = .tools
        default: 
            guard let platform:Platform = .init(rawValue: rawValue)
            else 
            {
                return nil 
            }
            self = .platform(platform)
        }
    }
    var rawValue:String 
    {
        switch self 
        {
        case .general:                  return "*"
        case .swift:                    return "Swift"
        case .tools:                    return "SwiftPM"
        case .platform(let platform):   return platform.rawValue
        }
    }
}
