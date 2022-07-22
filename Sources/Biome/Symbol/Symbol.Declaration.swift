import SymbolGraphs
import Notebook

extension Symbol 
{
    struct Declaration:Equatable
    {
        // signatures and declarations can change without disturbing the symbol identifier, 
        // since they contain information that is not part of ABI.
        let fragments:Notebook<Highlight, Index>
        let signature:Notebook<Highlight, Never>
        // generic parameter *names* are not part of ABI.
        let generics:[Generic]
        // these *might* be version-independent, but right now we are storing generic 
        // parameter/associatedtype names
        let genericConstraints:[Generic.Constraint<Index>]
        let extensionConstraints:[Generic.Constraint<Index>]
        let availability:Availability
        
        init(fallback:String) 
        {
            let fallback:CollectionOfOne<(String, Highlight)> = 
                .init((fallback, .text))
            
            self.signature = .init(fallback)
            self.fragments = .init()
            self.generics = []
            self.genericConstraints = []
            self.extensionConstraints = []
            self.availability = .init()
        }
        
        init(_ vertex:Vertex.Frame, scope:Scope) throws 
        {
            self.availability = vertex.availability 
            self.generics = vertex.generics
            self.signature = vertex.signature
            // even with mythical symbol inference, it is still possible for 
            // declarations to reference non-existent USRs, e.g. 'ss14_UnicodeParserP8EncodingQa'
            // (Swift._UnicodeParser.Encoding)
            self.fragments = vertex.declaration.compactMap 
            {
                // ignore warnings related to c-language symbols 
                guard case .swift = $0.language 
                else 
                {
                    return nil
                }
                do 
                {
                    return try scope.index(of: $0)
                }
                catch let error 
                {
                    print("warning: \(error) while generating symbol declaration")
                    return nil 
                }
            }
            self.genericConstraints = try vertex.genericConstraints.map
            {
                try $0.map(scope.index(of:))
            }
            self.extensionConstraints = try vertex.extensionConstraints.map
            {
                try $0.map(scope.index(of:))
            }
        }
    }
}
