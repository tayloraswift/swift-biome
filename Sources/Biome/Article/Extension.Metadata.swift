import struct SymbolGraphs.Path
import Markdown

extension Extension 
{
    struct Metadata 
    {
        var path:Path?
        var imports:Set<Module.ID> 
        var errors:[DirectiveArgumentText.ParseError]
        
        var noTitle:Bool
        
        init(directives:[BlockDirective])
        {
            self.path = nil
            self.errors = []
            self.imports = []
            
            self.noTitle = false
            
            let directives:[String: [BlockDirective]] = .init(grouping: directives, by: \.name)
            // @notitle 
            if  let anything:[BlockDirective] = directives["notitle"], !anything.isEmpty
            {
                self.noTitle = true
            }
            // @import(_:)
            if  let matches:[BlockDirective] = directives["import"]
            {
                for invocation:BlockDirective in matches 
                {
                    guard let imported:Substring = invocation.argumentText.segments.first?.trimmedText
                    else 
                    {
                        continue 
                    }
                    self.imports.insert(Module.ID.init(imported))
                }
            }
            // @path(_:)
            if  let matches:[BlockDirective] = directives["path"],
                let match:BlockDirective = matches.last
            {
                self.path = .init(match.argumentText.segments
                    .map(\.trimmedText)
                    .joined()
                    .split(separator: "/")
                    .map(String.init(_:)))
            }
        }
    }
}
