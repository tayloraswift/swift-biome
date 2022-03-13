import JSON 
import Resource

extension Documentation 
{
    private 
    func searchEntry(_ index:Int) -> JSON 
    {
        let uri:String = self.print(uri: uri(witness: index, victim: nil))
        let symbol:Biome.Symbol = self.biome.symbols[index]
        return .object(
        [
            "title": .string(symbol.title), 
            "uri":   .string(uri), 
            "text":   .array(symbol.signature.content.compactMap
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
    
    func searchIndex(for package:Biome.Package) -> Resource
    {
        let json:JSON = .array(package.modules.flatMap 
        { 
            (module:Int) -> FlattenSequence<[[JSON]]> in 
            let module:Biome.Module = self.biome.modules[module]
            return (module.symbols.extensions.map
            {
                $0.symbols.map(self.searchEntry(_:)) 
            }
            + 
            CollectionOfOne<[JSON]>.init(module.symbols.core.map(self.searchEntry(_:)))).joined()
        })
        let serialization:String = _move(json).description
        return .text(serialization, type: .json, version: package.hash)
    }
}
