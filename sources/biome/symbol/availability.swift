extension Biome 
{
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/AvailabilityMixin.cpp
    enum Domain:String, Sendable, Hashable  
    {
        case wildcard   = "*"
        case swift      = "Swift"
        case swiftpm    = "SwiftPM"
        
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
        
        static 
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
        }
    }
}

extension Symbol 
{
    struct UnconditionalAvailability:Sendable
    {
        var unavailable:Bool 
        var deprecated:Bool 
        var renamed:String?
        var message:String?
    }
    struct SwiftAvailability:Sendable
    {
        // unconditionals not allowed 
        var deprecated:Package.Version?
        var introduced:Package.Version?
        var obsoleted:Package.Version?
        var renamed:String?
        var message:String?
    }
    struct Availability:Sendable
    {
        var unavailable:Bool 
        // .some(nil) represents unconditional deprecation
        var deprecated:Package.Version??
        var introduced:Package.Version?
        var obsoleted:Package.Version?
        var renamed:String?
        var message:String?
    }
}
