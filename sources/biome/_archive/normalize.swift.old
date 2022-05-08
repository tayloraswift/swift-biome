import Grammar

extension Documentation
{    
    func normalize(uri:String) -> (uri:URI, changed:Bool)
    {
        var changed:Bool = false 
        let uri:URI = self.normalize(uri: uri, changed: &changed)
        return (uri, changed)
    }
    private 
    func normalize(uri:String, changed:inout Bool) -> URI
    {
        let path:Substring, 
            query:Substring?
        switch (question: uri.firstIndex(of: "?"), hash: uri.firstIndex(of: "#"))
        {
        case (question: let question?, hash: let hash?):
            guard question < hash 
            else 
            {
                fallthrough
            }
            path    = uri[..<question]
            query   = uri[question ..< hash].dropFirst()
        case (question: nil          , hash: let hash?):
            path    = uri[..<hash]
            query   = nil
        case (question: let question?, hash: nil):
            path    = uri[..<question]
            query   = uri[question...].dropFirst()
        case (question: nil          , hash: nil):
            path    = uri[...]
            query   = nil
        }
        
        let parameters:URI.Query? = self.biome.normalize(query: query, changed: &changed)
        // linear search will probably be faster than anything else 
        for base:URI.Base in [.biome, .learn]
        {
            // not currently needed, since self.normalize(base:path:changed:)
            // only writes to `changed` on success
            var changedThisAttempt:Bool = false
            guard let path:URI.Path = self.normalize(base: base, path: path, changed: &changedThisAttempt)
            else 
            {
                continue 
            }
            changed = changed || changedThisAttempt
            
            return .init(base: base, path: path, query: parameters)
        }
        
        // bogus path prefix. this usually happens when the surrounding 
        // server performs some kind of path normalization that doesn’t 
        // agree with the `bases` it initialized these docs with.
        changed = true 
        return .init(base: .biome, path: .init(stem: [], leaf: []), query: parameters)
    }
    private 
    func normalize(base:URI.Base, path:Substring, changed:inout Bool) -> URI.Path?
    {
        let prefix:String = self.routing[keyPath: base.offset]
        var characters:String.Iterator  = prefix.makeIterator()
        
        var start:String.Index = path.endIndex
        for index:String.Index in path.indices
        {
            guard let expected:Character = characters.next() 
            else 
            {
                start = index 
                break
            }
            guard path[index] == expected 
            else 
            {
                return nil
            }
        }
        let path:Substring.UTF8View = path[start...].utf8
        switch path.first 
        {
        case 0x2f?: 
            return .normalize(joined: path.dropFirst(), changed: &changed)
        
        case _?: // does not start with a '/'
            changed = true 
            fallthrough
        
        case nil: 
            // is completely empty (except for the prefix)
            return .init(stem: [], leaf: [])
        }
    }
}
extension Biome 
{
    func normalize(query:Substring?, changed:inout Bool) -> Documentation.URI.Query?
    {
        guard let query:Substring = query
        else 
        {
            return nil
        }
        // accept empty query, as this models the lone '?' suffix, which is distinct 
        // from `nil` query
        guard let query:[(key:[UInt8], value:[UInt8])] = 
            try? Grammar.parse(query.utf8, as: Documentation.URI.Rule<String.Index>.Query.self)
        else 
        {
            changed = true 
            return nil
        }
        
        changed = changed || query.isEmpty
        
        var witness:Int?    = nil  
        var victim:Int?     = nil
        
        for (key, value):([UInt8], [UInt8]) in query 
        {
            let id:(witness:Symbol.ID?, victim:Symbol.ID?)
            parameter:
            switch String.init(decoding: key, as: Unicode.UTF8.self)
            {
            case "self": 
                if let victim:Symbol.ID = try? Grammar.parse(value, as: URI.Rule<Array<UInt8>.Index, UInt8>.USR.OpaqueName.self)
                {
                    // if the mangled name contained a colon ('SymbolGraphGen style')
                    // get rid of it 
                    changed = changed || value.contains(0x3a) 
                    id      = (nil, victim)
                }
                else 
                {
                    changed = true
                    id      = (nil, nil)
                }
            
            case "overload": 
                switch try? Grammar.parse(value, as: URI.Rule<Array<UInt8>.Index, UInt8>.USR.self) 
                {
                case nil: 
                    changed = true 
                    continue  
                case .natural(let natural)?:
                    
                    changed = changed || value.contains(0x3a) 
                    id      = (natural, nil)
                
                case .synthesized(from: let witness, for: let victim)?:
                    // this is supported for backwards-compatibility, 
                    // but the `::SYNTHESIZED::` infix is deprecated, so issue 
                    // a redirect 
                    changed = true 
                    id      = (witness, victim)
                }

            default: 
                changed = true 
                continue  
            }
            
            if  let index:Int = id.witness.flatMap(self.symbols.index(of:))
            {
                if case nil = witness
                {
                    witness = index 
                }
                else 
                {
                    changed = true 
                }
            }
            if  let index:Int = id.victim.flatMap(self.symbols.index(of:))
            {
                if case nil = victim
                {
                    victim  = index 
                }
                else
                {
                    changed = true 
                }
            }
        }
        //  victim id without witness id is useless 
        return witness.map { .init(witness: $0, victim: victim) }
    }
}
