extension Biome 
{
    public 
    struct Version:CustomStringConvertible, Sendable
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
        
        public 
        var description:String 
        {
            switch (self.minor, self.patch)
            {
            case (nil       , nil):         return "\(self.major)"
            case (let minor?, nil):         return "\(self.major).\(minor)"
            case (let minor , let patch?):  return "\(self.major).\(minor ?? 0).\(patch)"
            }
        }
    }
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
        var deprecated:Biome.Version?
        var introduced:Biome.Version?
        var obsoleted:Biome.Version?
        var renamed:String?
        var message:String?
    }
    struct Availability:Sendable
    {
        var unavailable:Bool 
        // .some(nil) represents unconditional deprecation
        var deprecated:Biome.Version??
        var introduced:Biome.Version?
        var obsoleted:Biome.Version?
        var renamed:String?
        var message:String?
    }
}
