import Versions
import Notebook
import JSON 

extension SymbolGraph.Vertex:Sendable where Target:Sendable {}
extension SymbolGraph.Vertex:Equatable where Target:Equatable {}

extension SymbolGraph 
{
    @frozen public
    struct Vertex<Target>
    {
        public 
        var path:Path
        public 
        var community:Community 
        public 
        var declaration:Declaration<Target>
        public 
        var comment:String

        @inlinable public 
        init(path:Path,
            community:Community, 
            declaration:Declaration<Target>, 
            comment:String)
        {
            self.path = path
            self.community = community
            self.declaration = declaration
            self.comment = comment
        }

        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            try self.declaration.forEach(body)
        }
        @inlinable public 
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Vertex<T>
        {
            .init(path: self.path, 
                community: self.community, 
                declaration: try self.declaration.map(transform), 
                comment: self.comment)
        }
    }
}
extension SymbolGraph.Vertex 
{
    static 
    func `protocol`(named name:String) -> Self 
    {
        let fragments:[Notebook<Highlight, Target>.Fragment] = 
        [
            .init("protocol",   color: .keywordText),
            .init(" ",          color: .text),
            .init(name,         color: .identifier),
        ]
        return .init(path: .init(last: name), 
            community: .protocol, 
            declaration: .init(
                fragments: .init(fragments), 
                signature: .init(fragments)), 
            comment: "")
    }
}

extension SymbolGraph.Vertex<Int> 
{
    var serialized:JSON 
    {
        var items:[(key:String, value:JSON)] =
        [
            ("p", .array(self.path.map(JSON.string(_:)))),
            ("f", .array(self.declaration.fragments.map(\.serialized))),
            ("s", .array(self.declaration.signature.map(\.serialized))),
        ]
        if !self.declaration.availability.isEmpty
        {
            items.append(("a", self.declaration.availability.serialized))
        }
        if !self.declaration.extensionConstraints.isEmpty
        {
            items.append(("e", .array(self.declaration.extensionConstraints.map(\.serialized))))
        }
        if !self.declaration.genericConstraints.isEmpty
        {
            items.append(("c", .array(self.declaration.genericConstraints.map(\.serialized))))
        }
        if !self.declaration.generics.isEmpty
        {
            items.append(("g", .array(self.declaration.generics.map(\.serialized))))
        }
        if !self.comment.isEmpty 
        {
            items.append(("d", .string(self.comment)))
        }
        return .object(items)
    }
}
extension Notebook<Highlight, Int>.Fragment
{
    var serialized:JSON 
    {
        if let link:Int = self.link
        {
            return [.string(self.text), .number(self.color.rawValue), .number(link)]
        }
        else 
        {
            return [.string(self.text), .number(self.color.rawValue)]
        }
    }
}
extension Notebook<Highlight, Never>.Fragment
{
    var serialized:JSON 
    {
        [.string(self.text), .number(self.color.rawValue)]
    }
}
extension Generic 
{
    var serialized:JSON 
    {
        [
            .string(self.name),
            .number(self.index),
            .number(self.depth)
        ]
    }
}
extension Generic.Constraint<Int> 
{
    var serialized:JSON 
    {
        if let target:Int = self.target
        {
            return 
                [
                    .string(self.subject), 
                    .number(self.verb.rawValue), 
                    .string(self.object), 
                    .number(target),
                ]
        }
        else 
        {
            return 
                [
                    .string(self.subject), 
                    .number(self.verb.rawValue), 
                    .string(self.object), 
                ]
        }
    }
}
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