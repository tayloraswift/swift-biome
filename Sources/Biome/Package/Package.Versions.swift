import Versions

extension Package 
{
    struct Node:Sendable 
    {
        let version:PreciseVersion 
        let dependencies:[Package.Index: Version]
        var consumers:[Package.Index: Set<Version>]

        init(version:PreciseVersion, dependencies:[Package.Index: Version],
            consumers:[Package.Index: Set<Version>] = [:])
        {
            self.version = version
            self.consumers = consumers
            self.dependencies = dependencies 
        }
    }

    struct Versions:RandomAccessCollection, Sendable 
    {
        var latest:Version
        {
            .init(offset: self.nodes.endIndex - 1)
        }
        
        private
        var nodes:[Node], 
            mapping:[MaskedVersion?: Version]
        let package:Package.Index
        
        var startIndex:Version 
        {
            .init(offset: self.nodes.startIndex)
        }
        var endIndex:Version 
        {
            .init(offset: self.nodes.endIndex)
        }
        subscript(version:Version) -> Node 
        {
            _read 
            {
                yield  self.nodes[version.offset]
            }
            _modify 
            {
                yield &self.nodes[version.offset]
            }
        }

        func pins(at version:Version) -> Pins
        {
            .init(local: (self.package, version), dependencies: self[version].dependencies)
        }
        func pins(at masked:MaskedVersion?) -> Pins?
        {
            self.mapping[masked].map(self.pins(at:))
        }
        
        func snap(_ masked:MaskedVersion?) -> Version
        {
            self.mapping[masked] ?? self.latest
        }
        
        init(package:Package.Index)
        {
            self.package = package 
            self.mapping = [:]
            self.nodes = []
        }
        
        mutating 
        func push(_ precise:PreciseVersion, dependencies:[Package.Index: Version]) -> Pins
        {
            self.nodes.append(.init(version: precise, dependencies: dependencies))
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
            return .init(local: (self.package, version), dependencies: dependencies)
        }
        
        func abbreviate(_ version:Version) -> MaskedVersion?
        {
            guard self.latest != version 
            else 
            {
                return nil 
            }
            switch self[version].version 
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
