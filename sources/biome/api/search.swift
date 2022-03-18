import JSON 
import Resource

extension Biome 
{
    private 
    func searchEntry(_ index:Int, routing:Documentation.RoutingTable) -> JSON 
    {
        let uri:String = self.print(prefix: routing.prefix, 
            uri: self.uri(witness: index, victim: nil, routing: routing))
        let symbol:Symbol = self.symbols[index]
        return .object(
        [
            ("title", .string(symbol.title)), 
            ("uri"  , .string(uri)), 
            ("text" , .array(symbol.signature.content.compactMap
            {
                (text:String, highlight:SwiftHighlight) in
                switch highlight
                {
                case .identifier, .keywordIdentifier, .argument: 
                    return JSON.string(text)
                default: 
                    return nil
                }
            })),
        ]) 
    }
    private 
    func searchIndex(for package:Package, routing:Documentation.RoutingTable) -> Resource
    {
        let json:JSON = .array(package.modules.flatMap 
        { 
            (module:Int) -> FlattenSequence<[[JSON]]> in 
            let module:Module = self.modules[module]
            return (module.symbols.extensions.map
            {
                $0.symbols.map
                {
                    self.searchEntry($0, routing: routing)
                }
            }
            + 
            CollectionOfOne<[JSON]>.init(module.symbols.core.map
                {
                    self.searchEntry($0, routing: routing)
                })).joined()
        })
        let serialization:String = _move(json).description
        return .text(serialization, type: .json, version: package.hash)
    }
    func searchIndices(routing:Documentation.RoutingTable) -> [Resource]
    {
        self.packages.map { self.searchIndex(for: $0, routing: routing) }
    }
}
