extension Documentation.ArticleRenderer 
{
    /* func resolve(entrapta text:String) throws -> Documentation.Index
    {
        //  ``relativename`` -> ['package-name/relativename', 'package-name/modulename/relativename']
        //  ``/absolutename`` -> ['absolutename']
        let path:Documentation.URI.Path
        let resolved:Documentation.Index
        var ignored:Bool    = false 
        if case "/"? = text.first
        {
            path = .normalize(joined: text.dropFirst().utf8, changed: &ignored)
            if let (index, _):(Documentation.Index, Bool) = self.routing.resolve(base: .biome, path: path, overload: nil)
            {
                resolved = index
            }
            else 
            {
                throw Documentation.ArticleError.undefinedSymbolLink(path, overload: nil)
            }
        }
        else 
        {
            path = .normalize(joined: text[...].utf8, changed: &ignored)
            if      let first:[UInt8] = path.stem.first, 
                        first == self.biome.trunk(namespace: self.context.namespace),
                    let (index, _):(Documentation.Index, Bool) = self.routing.resolve(
                        namespace: self.context.namespace, 
                        stem: path.stem.dropFirst(1), 
                        leaf: path.leaf, 
                        overload: nil)
            {
                resolved = index 
            }
            else if let (index, _):(Documentation.Index, Bool) = self.routing.resolve(
                        namespace: self.context.namespace, 
                        stem: path.stem[...], 
                        leaf: path.leaf, 
                        overload: nil)
            {
                resolved = index 
            }
            else 
            {
                throw Documentation.ArticleError.undefinedSymbolLink(path, overload: nil)
            }
        }
        if case .ambiguous = resolved 
        {
            throw Documentation.ArticleError.ambiguousSymbolLink(path, overload: nil)
        }
        return resolved
    } */
}
