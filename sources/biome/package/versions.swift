extension Package 
{
    struct Versions:Sendable 
    {
        var latest:Version
        {
            .init(offset: self.storage.endIndex - 1)
        }
        
        private
        var storage:[Pins<PreciseVersion>], 
            mapping:[MaskedVersion?: Version]
        
        subscript(version:Version) -> PreciseVersion
        {
            _read 
            {
                yield self.storage[version.offset].local
            }
        }
        subscript(masked:MaskedVersion?) -> Pins<Version>?
        {
            self.mapping[masked].map 
            {
                .init(local: $0, upstream: self.storage[$0.offset].upstream)
            }
        }
        
        func snap(_ masked:MaskedVersion?) -> Version
        {
            self.mapping[masked] ?? self.latest
        }
        
        init()
        {
            self.storage = []
            self.mapping = [:]
        }
        
        mutating 
        func push(_ precise:PreciseVersion, upstream:[Index: Version])
            -> Pins<Version>
        {
            self.storage.append(.init(local: precise, upstream: upstream))
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
            return .init(local: version, upstream: upstream)
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
        
        func filter(_ predicate:(Version) throws -> Bool) rethrows -> [Version]
        {
            try self.storage.indices.lazy.map(Version.init(offset:)).filter(predicate) 
        }
    }
}
