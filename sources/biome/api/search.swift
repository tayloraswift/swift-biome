import JSON 
import Resource

extension Language.Lexeme 
{
    var search:String? 
    {
        switch self 
        {
        case    .code(let text, class: .argument),
                .code(let text, class: .identifier),
                .code(let text, class: .keyword(.`init`)),
                .code(let text, class: .keyword(.deinit)),
                .code(let text, class: .keyword(.subscript)):
            return text.lowercased() 
        default: 
            return nil
        }
    }
}
extension Biome.Symbol 
{
    var search:JSON
    {
        .object(
        [
            "title": .string(self.title), 
            "uri":   .string(self.path.description), 
            "text":   .array(self.signature.compactMap
            {
                $0.search.map(JSON.string(_:))
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
