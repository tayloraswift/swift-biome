import JSON 

public 
enum Entrapta 
{
    public static 
    func documentation(symbolgraph utf8:[UInt8]) throws -> Documentation
    {
        let json:JSON   = try Grammar.parse(utf8, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
        let graph:Graph = try .init(from: json)
        let documentation:Documentation = .init(graph: graph)
        
        return documentation
    }
}
