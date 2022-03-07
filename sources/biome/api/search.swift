import JSON 
import Resource

extension Biome.Symbol 
{
    var search:JSON
    {
        .object(
        [
            "title": .string(self.title), 
            "uri":   .string(self.path.description), 
            "text":   .array(self.signature.content.compactMap
            {
                (text:String, highlight:SwiftHighlight) in
                switch highlight
                {
                case .identifier, .keywordIdentifier, .argument: 
                    return JSON.string(text)
                default: 
                    return nil
                }
            }),
        ]) 
    }
}
extension Biome 
{
    @available(*, deprecated)
    var search:[(uri:String, title:String, text:[String])]
    {
        fatalError("unreachable")
    }
    
    func searchIndex(for package:Package) -> Resource
    {
        let json:JSON = .array(package.modules.flatMap 
        { 
            (module:Int) -> FlattenSequence<[[JSON]]> in 
            let module:Module = self.modules[module]
            return (module.symbols.extensions.map
            {
                $0.symbols.map 
                {
                    self.symbols[$0].search
                }
            }
            + 
            CollectionOfOne<[JSON]>.init(module.symbols.core.map 
            {
                self.symbols[$0].search
            })).joined()
        })
        let serialization:String = _move(json).description
        return .text(serialization, type: .json, version: package.hash)
    }
}
