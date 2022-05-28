import HTML

extension DocumentElement where Domain == HTML 
{
    static 
    func highlight(_ text:String, _ color:Fragment.Color) -> Self
    {
        let css:[String]
        switch color
        {
        case .text: 
            return .text(escaping: text)
        case .type:
            css = ["syntax-type"]
        case .identifier:
            css = ["syntax-identifier"]
        case .generic:
            css = ["syntax-generic"]
        case .argument:
            css = ["syntax-parameter-label"]
        case .parameter:
            css = ["syntax-parameter-name"]
        case .directive, .attribute, .keywordText:
            css = ["syntax-keyword"]
        case .keywordIdentifier:
            css = ["syntax-keyword", "syntax-keyword-identifier"]
        case .pseudo:
            css = ["syntax-pseudo-identifier"]
        case .number, .string:
            css = ["syntax-literal"]
        case .interpolation:
            css = ["syntax-interpolation-anchor"]
        case .keywordDirective:
            css = ["syntax-macro"]
        case .newlines:
            css = ["syntax-newline"]
        case .comment, .documentationComment:
            css = ["syntax-comment"]
        case .invalid:
            css = ["syntax-invalid"]
        }
        return .span(text) { css }
    } 
}
