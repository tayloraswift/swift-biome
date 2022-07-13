import JSON 
import Resources

struct SearchIndexCache:Cache 
{
    private
    var cache:[Package.Index: Resource]
    
    subscript(package:Package.Index) -> Resource?
    {
        _read 
        {
            yield self.cache[package]
        }
    }
    
    init()
    {
        self.cache = [:]
    }
    mutating 
    func regenerate(for package:Package.Index, from ecosystem:Ecosystem)
    {
        self.cache[package] = Self.generate(for: package, from: ecosystem)
    }
    private static 
    func generate(for package:Package.Index, from ecosystem:Ecosystem) -> Resource
    {
        let current:Package.Pinned = ecosystem[package].pinned()
        let modules:[JSON] = current.package.modules.all.map 
        {
            var types:[JSON] = []
            for colony:Symbol.ColonialRange in $0.symbols 
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
                    let uri:URI = ecosystem.uri(of: .init(natural: index), in: current)
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
        let json:JSON = .array(_move(modules))
        let bytes:[UInt8] = .init(_move(json).description.utf8)
        return .init(hashing: bytes, type: .utf8(encoded: .json))
    }
}
