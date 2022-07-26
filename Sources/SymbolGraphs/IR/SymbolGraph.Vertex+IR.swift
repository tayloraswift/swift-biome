import Notebook 
import JSON

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