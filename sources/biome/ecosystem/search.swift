import JSON 
import Resource

extension Ecosystem 
{
    func generateSearchIndexCache() -> [Package.Index: Resource]
    {
        .init(uniqueKeysWithValues: self.packages.map 
        {
            ($0.index, self.generateSearchIndexOfTypes(in: $0))
        })
    }
    private 
    func generateSearchIndexOfTypes(in package:Package) -> Resource
    {
        let current:Package.Pinned = .init(package, at: package.versions.latest)
        let modules:[JSON] = current.package.modules.all.map 
        {
            var types:[JSON] = []
            for colony:Symbol.ColonialRange in $0.matrix 
            {
                for offset:Int in colony.offsets 
                {
                    let index:Symbol.Index = .init($0.index, offset: offset)
                    
                    let symbol:Symbol = current.package[local: index]
                    switch symbol.color
                    {
                    case .protocol, .typealias, .concretetype(_), .global(_):
                        break 
                    case .associatedtype, .callable(_): 
                        continue
                    }
                    
                    let declaration:Symbol.Declaration = current.declaration(index)
                    let uri:URI = self.uri(of: .symbol(index), in: current)
                    let keywords:[JSON] = declaration.signature.compactMap
                    {
                        switch $0.color 
                        {
                        case .identifier, .keywordIdentifier, .argument: 
                            return JSON.string($0.text)
                        default: 
                            return nil
                        }
                    }
                    types.append(.object(
                    [
                        ("s", .array(keywords)),
                        ("t", .string(symbol.description)), 
                        ("u", .string(uri.description)), 
                    ]))
                }
            }
            let module:String = .init($0.title)
            return .object([("module", .string(module)), ("symbols", .array(types))])
        }
        let tag:String = "lunr:0.1.0/\(package.name)"
        let json:JSON = .array(_move(modules))
        let bytes:[UInt8] = .init(_move(json).description.utf8)
        return .utf8(encoded: bytes, type: .json, tag: .init(tag))
    }
}
