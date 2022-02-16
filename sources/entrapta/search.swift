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
extension Entrapta.Graph.Symbol 
{
    var search:(uri:String, title:String, text:[String])
    {
        (self.path.canonical, self.title, self.signature.compactMap(\.search))
    }
}
extension Entrapta.Graph 
{
    var search:[(uri:String, title:String, text:[String])]
    {
        self.symbols.values.map(\.search)
    }
}
