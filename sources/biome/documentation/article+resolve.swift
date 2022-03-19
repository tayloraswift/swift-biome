extension Documentation
{
    enum Tool 
    {
        case entrapta
        case docc
    }
}
extension Documentation.ArticleRenderer 
{
    func resolve(docc text:String) throws -> Documentation.Index
    {
        let hyphen:String.Index?    = text.firstIndex(of: "-") 
        let capitalized:Bool?       = try hyphen.map 
        {
            let suffix:String       = String.init(text[$0...].dropFirst())
            guard let kind:Biome.Symbol.Kind = .init(rawValue: suffix)
            else 
            {
                throw Documentation.ArticleError.invalidDocCSymbolLinkSuffix(suffix)
            }
            return kind.capitalized
        }
        
        let text:Substring = hyphen.map(text.prefix(upTo:)) ?? text[...]
        //  ``relativename`` -> ['package-name/relativename', 'package-name/modulename/relativename']
        var ignored:Bool    = false 
        let path:Documentation.URI.Path = .normalize(joined: text.utf8, changed: &ignored)
        
        guard path.leaf.isEmpty  
        else 
        {
            fatalError("docc symbol link cannot contain a leaf")
        }
        
        var options:[(stem:ArraySlice<[UInt8]>, leaf:[UInt8])] = []
        
        if !(capitalized ?? false), let leaf:[UInt8] = path.stem.last 
        {
            // if the symbol is a traditionally-lowercased symbol, or we don’t know,
            // try resolving it with the last stem component as a leaf.
            options.append((path.stem.dropLast(), leaf))
        }
        if capitalized ?? true 
        {
            // if the symbol is a traditionally-capitalized symbol, or we don’t know,
            // try resolving it with no leaf.
            options.append((path.stem[...], path.leaf))
        } 
        if  let first:[UInt8] = path.stem.first, 
            case self.context.namespace? = self.routing.trunks[first]
        {
            // if the first stem component matches a module name, and it’s the 
            // same as the current namespace context, try resolving it 
            // with the module prefix removed. check this *first*, so that 
            // we can reference a module like `JSON` as `JSON`, and its type of 
            // the same name as `JSON.JSON`.
            for (stem, leaf):(ArraySlice<[UInt8]>, [UInt8]) in options 
                where !stem.isEmpty
            {
                options.append((stem.dropFirst(), leaf))
            }
        }
        
        for (stem, leaf):(ArraySlice<[UInt8]>, [UInt8]) in options.reversed() 
        {
            guard let (index, _):(Documentation.Index, Bool) = 
                self.routing.resolve(namespace: self.context.namespace, stem: stem, leaf: leaf, overload: nil)
            else 
            {
                continue 
            }
            if case .ambiguous = index 
            {
                throw Documentation.ArticleError.ambiguousSymbolLink(path, overload: nil)
            }
            return index
        }
        throw Documentation.ArticleError.undefinedSymbolLink(path, overload: nil)
            
    }
    func resolve(entrapta text:String) throws -> Documentation.Index
    {
        //  ``relativename`` -> ['package-name/relativename', 'package-name/modulename/relativename']
        //  ``/absolutename`` -> ['absolutename']
        let path:Documentation.URI.Path
        let resolved:Documentation.Index
        var ignored:Bool    = false 
        if case "/"? = text.first
        {
            path = .normalize(joined: text.dropFirst().utf8, changed: &ignored)
            if let (index, _):(Documentation.Index, Bool) = self.routing.resolve(path: path, overload: nil)
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
    }
}
