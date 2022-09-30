import JSON
import SymbolAvailability
import Versions

extension IR 
{
    enum Availability 
    {
        static let swift:String = "s"
        static let general:String = "a"

        static let unavailable:String = "u"
        static let deprecated:String = "d"
        static let introduced:String = "i"
        static let obsoleted:String = "o"
        static let renamed:String = "r"
        static let message:String = "m"
    }
}
extension Availability 
{
    init(from json:JSON) throws 
    {
        self = try json.lint
        {
            let swift:SwiftAvailability? = 
                try $0.pop(IR.Availability.swift, SwiftAvailability.init(from:))
            let general:UnversionedAvailability? = 
                try $0.pop(IR.Availability.general, UnversionedAvailability.init(from:))
            var platforms:[Platform: VersionedAvailability] = [:]
            for key:String in $0.items.keys 
            {
                if let platform:Platform = .init(rawValue: key)
                {
                    platforms[platform] = try $0.remove(key, VersionedAvailability.init(from:))
                }
            }
            return .init(swift: swift, general: general, platforms: platforms)
        }
    }
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if let general:UnversionedAvailability = self.general
        {
            items.append((IR.Availability.general, general.serialized))
        }
        if let swift:SwiftAvailability = self.swift 
        {
            items.append((IR.Availability.swift, swift.serialized))
        }
        for platform:Platform in Platform.allCases 
        {
            if let versioned:VersionedAvailability = self.platforms[platform]
            {
                items.append((platform.rawValue, versioned.serialized))
            }
        }
        return .object(items)
    }
}
extension SwiftAvailability 
{
    init(from json:JSON) throws 
    {
        self = try json.lint
        {
            .init(
                deprecated: try $0.pop(IR.Availability.deprecated, as: String.self)
                    .map(SemanticVersion.Masked.init(parsing:)),
                introduced: try $0.pop(IR.Availability.introduced, as: String.self)
                    .map(SemanticVersion.Masked.init(parsing:)), 
                obsoleted: try $0.pop(IR.Availability.obsoleted, as: String.self)
                    .map(SemanticVersion.Masked.init(parsing:)), 
                renamed: try $0.pop(IR.Availability.renamed, as: String.self),
                message: try $0.pop(IR.Availability.message, as: String.self)
            )
        }
    }
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if let deprecated:SemanticVersion.Masked = self.deprecated
        {
            items.append((IR.Availability.deprecated, .string(deprecated.description)))
        }
        if let introduced:SemanticVersion.Masked = self.introduced
        {
            items.append((IR.Availability.introduced, .string(introduced.description)))
        }
        if let obsoleted:SemanticVersion.Masked = self.obsoleted
        {
            items.append((IR.Availability.obsoleted, .string(obsoleted.description)))
        }
        if let renamed:String = self.renamed
        {
            items.append((IR.Availability.renamed, .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append((IR.Availability.message, .string(message)))
        }
        return .object(items)
    }
}
extension VersionedAvailability 
{
    init(from json:JSON) throws 
    {
        self = try json.lint
        {
            .init(
                unavailable: try $0.pop(IR.Availability.unavailable, as: Bool.self) ?? false,
                deprecated: try $0.pop(IR.Availability.deprecated)
                {
                    (variant:JSON) -> Deprecation? in 
                    switch variant 
                    {
                    case .bool(true):
                        return .always
                    case .string(let string):
                        return .since(try .init(parsing: string))
                    default: 
                        return nil
                    }
                } ?? nil,
                introduced: try $0.pop(IR.Availability.introduced, as: String.self)
                    .map(SemanticVersion.Masked.init(parsing:)), 
                obsoleted: try $0.pop(IR.Availability.obsoleted, as: String.self)
                    .map(SemanticVersion.Masked.init(parsing:)), 
                renamed: try $0.pop(IR.Availability.renamed, as: String.self),
                message: try $0.pop(IR.Availability.message, as: String.self)
            )
        }
    }
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if self.unavailable
        {
            items.append((IR.Availability.unavailable, true))
        }
        switch self.deprecated
        {
        case nil: 
            break 
        case .always?:
            items.append((IR.Availability.deprecated, true))
        case .since(let deprecated)?:
            items.append((IR.Availability.deprecated, .string(deprecated.description)))
        }
        if let introduced:SemanticVersion.Masked = self.introduced
        {
            items.append((IR.Availability.introduced, .string(introduced.description)))
        }
        if let obsoleted:SemanticVersion.Masked = self.obsoleted
        {
            items.append((IR.Availability.obsoleted, .string(obsoleted.description)))
        }
        if let renamed:String = self.renamed
        {
            items.append((IR.Availability.renamed, .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append((IR.Availability.message, .string(message)))
        }
        return .object(items)
    }
}
extension UnversionedAvailability 
{
    init(from json:JSON) throws 
    {
        self = try json.lint
        {
            .init(
                unavailable: try $0.pop(IR.Availability.unavailable, as: Bool.self) ?? false,
                deprecated: try $0.pop(IR.Availability.deprecated, as: Bool.self) ?? false,
                renamed: try $0.pop(IR.Availability.renamed, as: String.self),
                message: try $0.pop(IR.Availability.message, as: String.self)
            )
        }
    }
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if self.unavailable
        {
            items.append((IR.Availability.unavailable, true))
        }
        if self.deprecated
        {
            items.append((IR.Availability.deprecated, true))
        }
        if let renamed:String = self.renamed
        {
            items.append((IR.Availability.renamed, .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append((IR.Availability.message, .string(message)))
        }
        return .object(items)
    }
}