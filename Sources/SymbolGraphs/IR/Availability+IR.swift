import Versions 
import JSON

extension Availability 
{
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if let general:UnversionedAvailability = self.general
        {
            items.append(("a", general.serialized))
        }
        if let swift:SwiftAvailability = self.swift 
        {
            items.append(("s", swift.serialized))
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
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if let deprecated:MaskedVersion = self.deprecated
        {
            items.append(("d", .string(deprecated.description)))
        }
        if let introduced:MaskedVersion = self.introduced
        {
            items.append(("i", .string(introduced.description)))
        }
        if let obsoleted:MaskedVersion = self.obsoleted
        {
            items.append(("o", .string(obsoleted.description)))
        }
        if let renamed:String = self.renamed
        {
            items.append(("r", .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append(("m", .string(message)))
        }
        return .object(items)
    }
}
extension VersionedAvailability 
{
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if self.unavailable
        {
            items.append(("u", true))
        }
        if let deprecated:MaskedVersion? = self.deprecated
        {
            items.append(("d", (deprecated?.description).map(JSON.string(_:)) ?? true))
        }
        if let introduced:MaskedVersion = self.introduced
        {
            items.append(("i", .string(introduced.description)))
        }
        if let obsoleted:MaskedVersion = self.obsoleted
        {
            items.append(("o", .string(obsoleted.description)))
        }
        if let renamed:String = self.renamed
        {
            items.append(("r", .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append(("m", .string(message)))
        }
        return .object(items)
    }
}
extension UnversionedAvailability 
{
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] = []
        if self.unavailable
        {
            items.append(("u", true))
        }
        if self.deprecated
        {
            items.append(("d", true))
        }
        if let renamed:String = self.renamed
        {
            items.append(("r", .string(renamed)))
        }
        if let message:String = self.message
        {
            items.append(("m", .string(message)))
        }
        return .object(items)
    }
}