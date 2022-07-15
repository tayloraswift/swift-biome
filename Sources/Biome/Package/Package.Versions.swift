extension Package 
{
    struct Versions:RandomAccessCollection, Sendable 
    {
        typealias Element = Pins
        
        var latest:Version
        {
            .init(offset: self.storage.endIndex - 1)
        }
        
        private
        var storage:[(local:PreciseVersion, upstream:[Package.Index: Version])], 
            mapping:[MaskedVersion?: Version]
        let package:Package.Index
        
        var startIndex:Version 
        {
            .init(offset: self.storage.startIndex)
        }
        var endIndex:Version 
        {
            .init(offset: self.storage.endIndex)
        }
        
        subscript(version:Version) -> Pins
        {
            .init(local: (self.package, version), 
                upstream: self.storage[version.offset].upstream)
        }
        subscript(masked:MaskedVersion?) -> Pins?
        {
            self.mapping[masked].map { self[$0] }
        }
        
        func precise(_ version:Version) -> PreciseVersion
        {
            self.storage[version.offset].local
        }
        
        func snap(_ masked:MaskedVersion?) -> Version
        {
            self.mapping[masked] ?? self.latest
        }
        
        init(package:Package.Index)
        {
            self.package = package 
            self.storage = []
            self.mapping = [:]
        }
        
        mutating 
        func push(_ precise:PreciseVersion, upstream:[Package.Index: Version]) -> Pins
        {
            self.storage.append((local: precise, upstream: upstream))
            let version:Version = self.latest 
            switch precise 
            {
            case .semantic(let major, let minor, let patch, let edition):
                self.mapping[.edition(major, minor, patch, edition)] = version
                self.mapping[  .patch(major, minor, patch)] = version
                self.mapping[  .minor(major, minor)] = version
                self.mapping[  .major(major)] = version
            case .toolchain(year: let year, month: let month, day: let day, letter: let letter):
                self.mapping[.hourly(year: year, month: month, day: day, letter: letter)] = version
                self.mapping[.nightly(year: year, month: month, day: day)] = version
            }
            self.mapping[nil] = version
            return .init(local: (self.package, version), upstream: upstream)
        }
        
        func abbreviate(_ version:Version) -> MaskedVersion?
        {
            guard self.latest != version 
            else 
            {
                return nil 
            }
            switch self.storage[version.offset].local 
            {
            case .semantic(let major, let minor, let patch, let edition):
                if      case version? = self.mapping[.major(major)]
                {
                    return .major(major)
                }
                else if case version? = self.mapping[.minor(major, minor)]
                {
                    return .minor(major, minor)
                }
                else if case version? = self.mapping[.patch(major, minor, patch)]
                {
                    return .patch(major, minor, patch)
                }
                else
                {
                    return .edition(major, minor, patch, edition)
                }
            
            case .toolchain(year: let year, month: let month, day: let day, letter: let letter):
                if      case version? = self.mapping[.nightly(year: year, month: month, day: day)]
                {
                    return .nightly(year: year, month: month, day: day)
                }
                else
                {
                    return .hourly(year: year, month: month, day: day, letter: letter)
                }
            }
        }
    }
}
