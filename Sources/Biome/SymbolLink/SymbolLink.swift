import SymbolGraphs
import URI

struct GlobalLink:RandomAccessCollection 
{
    enum Parameter:String 
    {
        case base     = "overload"
        case host     = "self"
        case culture  = "from"
    }

    var nationality:_SymbolLink.Nationality?
    var base:Symbol.ID?
    var host:Symbol.ID?

    private 
    let components:[String]
    private(set)
    var startIndex:Int 
    let fold:Int 
    var endIndex:Int 
    {
        self.components.endIndex
    }
    subscript(index:Int) -> String
    {
        _read 
        {
            yield self.components[index]
        }
    }

    init(_ uri:URI)  
    {
        self.init(uri.path)
        if let query:[URI.Parameter] = uri.query 
        {
            self.update(with: query)
        }
    }
    
    init(_ vectors:some Sequence<URI.Vector?>)  
    {
        (self.components, self.fold) = vectors.normalized
        self.startIndex = self.components.startIndex
        self.nationality = nil 
        self.base = nil 
        self.host = nil 
    }

    mutating 
    func update(with parameters:some Sequence<URI.Parameter>)
    {
        for (key, value):(String, String) in parameters 
        {
            switch Parameter.init(rawValue: key)
            {
            case nil: 
                continue 
            
            case .culture?:
                // either 'from=swift-foo' or 'from=swift-foo/0.1.2'. 
                // we do not tolerate missing slashes
                var separator:String.Index = value.firstIndex(of: "/") ?? value.endIndex
                let id:Package.ID = .init(value[..<separator])

                while separator < value.endIndex, value[separator] != "/"
                {
                    value.formIndex(after: &separator)
                }
                self.nationality = .init(id: id, version: .init(parsing: value[separator...]))
            
            case .host?:
                // if the mangled name contained a colon ('SymbolGraphGen style'), 
                // the parsing rule will remove it.
                if  let host:Symbol.ID = 
                        try? USR.Rule<String.Index>.OpaqueName.parse(value.utf8)
                {
                    self.host = host
                }
            
            case .base?: 
                switch try? USR.init(parsing: value.utf8) 
                {
                case nil: 
                    continue 
                
                case .natural(let base)?:
                    self.base = base
                
                case .synthesized(from: let base, for: let host)?:
                    // this is supported for backwards-compatibility, 
                    // but the `::SYNTHESIZED::` infix is deprecated, 
                    // so this will end up causing a redirect 
                    self.host = host
                    self.base = base 
                }
            }
        }
    }

    mutating 
    func descend() -> String?
    {
        if let first:String = self.first 
        {
            self.startIndex += 1 
            return first
        }
        else 
        {
            return nil 
        }
    }
    mutating 
    func descend<T>(where transform:(String) throws -> T?) rethrows -> T? 
    {
        if  let first:String = self.first, 
            let transformed:T = try transform(first)
        {
            self.startIndex += 1 
            return transformed
        }
        else 
        {
            return nil 
        }
    }
}

struct _SymbolLink:RandomAccessCollection
{
    // warning: do not make ``Equatable``, unless we enforce the correctness 
    // of the `hyphen` field!
    struct Component 
    {
        private(set)
        var string:String 
        private(set)
        var hyphen:String.Index?

        init(_ string:String, hyphen:String.Index? = nil)
        {
            self.string = string 
            self.hyphen = hyphen
        }

        mutating 
        func removeDocCFragment(global:Bool) -> Disambiguator.DocC?
        {
            guard let hyphen:String.Index = self.hyphen
            else 
            {
                return nil 
            }

            let text:Substring = self.string[self.string.index(after: hyphen)...]
            let disambiguator:Disambiguator.DocC?
            // will never collide with symbol communities, since they always contain 
            // a period ('.')
            // https://github.com/apple/swift-docc/blob/d94139a5e64e9ecf158214b1cded2a2880fc1b02/Sources/SwiftDocC/Utility/FoundationExtensions/String%2BHashing.swift
            if let hash:UInt32 = .init(text, radix: 36)
            {
                disambiguator = .fnv(hash: hash)
            }
            else if let community:Community = .init(declarationKind: text, global: global)
            {
                disambiguator = .community(community)
            }
            else 
            {
                disambiguator = nil
            }
            if case _? = disambiguator 
            {
                self.string = .init(self.string[..<hyphen])
                self.hyphen = nil 
            }
            return disambiguator
        }
    }
    struct Path:RandomAccessCollection 
    {
        private
        var components:[Component]
        private(set)
        var startIndex:Int
        private(set)
        var orientation:Orientation
        
        var endIndex:Int 
        {
            self.components.endIndex
        }
        subscript(index:Int) -> Component
        {
            _read 
            {
                yield  self.components[index]
            }
            _modify
            {
                yield &self.components[index]
            }
        }

        var first:Component 
        {
            _read 
            {
                yield  self.components[self.startIndex]
            }
            _modify 
            {
                yield &self.components[self.startIndex]
            }
        }
        var last:Component 
        {
            _read 
            {
                yield  self.components[self.index(before: self.endIndex)]
            }
            _modify 
            {
                yield &self.components[self.index(before: self.endIndex)]
            }
        }

        init?(_ components:some Collection<some StringProtocol>) throws 
        {
            try self.init(components: components, fold: components.startIndex)
        }
        init?(_ vectors:some Collection<URI.Vector?>) throws 
        {
            let (components, fold):([String], Int) = vectors.normalized 
            try self.init(components: components, fold: fold)
        }
        init?<Path>(components:Path, fold:Path.Index) throws
            where Path:Collection, Path.Element:StringProtocol
        {
            // iii. semantic segmentation 
            //
            // [     'foo',       'bar',       'baz.bar',                     '.Foo',          '..'] becomes
            // [.big("foo"), .big("bar"), .big("baz"), .little("bar"), .little("Foo"), .little("..")] 
            //                                                                         ^~~~~~~~~~~~~~~
            //                                                                          (visible = 1)
            self.orientation = .straight
            self.components = []
            self.components.reserveCapacity(components.underestimatedCount)
            self.startIndex = self.components.startIndex 
            // it is valid to pass an index for `fold` that is outside the bounds of 
            // the components collection!
            if components.startIndex < fold
            {
                try self.append(components: components[..<fold])
                self.startIndex = self.components.endIndex
                try self.append(components: components[fold...])
            }
            else 
            {
                try self.append(components: components)
            }
            if self.isEmpty 
            {
                return nil 
            }
        }

        var revealed:Self 
        {
            var revealed:Self = self 
                revealed.startIndex = revealed.components.startIndex 
            return revealed
        }
        var suffix:Self?
        {
            var suffix:Self = self 
                suffix.startIndex += 1
            return suffix.startIndex < suffix.endIndex ? suffix : nil
        }
        var outed:Self? 
        {
            switch self.orientation 
            {
            case .gay: 
                return nil 
            case .straight: 
                var outed:Self = self 
                    outed.orientation = .gay 
                return outed 
            }
        }

        private mutating 
        func append<S>(components:some Sequence<S>) throws where S:StringProtocol 
        {
            for component:S in components
            {
                switch try Symbol.Link.ComponentSegmentation<String.Index>.init(parsing: component)
                {
                case .opaque(let hyphen): 
                    self.components.append(.init(String.init(component), hyphen: hyphen))
                    self.orientation = .straight 
                case .big:
                    self.components.append(.init(String.init(component)))
                    self.orientation = .straight 
                
                case .little                      (let start):
                    // an isolated little-component implies an empty big-predecessor, 
                    // and therefore resets the visibility counter
                    self.startIndex = self.components.endIndex
                    self.components.append(.init(String.init(component[start...])))
                    self.orientation = .gay 
                
                case .reveal(big: let end, little: let start):
                    self.components.append(.init(String.init(component[..<end])))
                    self.components.append(.init(String.init(component[start...])))
                    self.orientation = .gay 
                }
            }
        }
    }
    struct Disambiguator 
    {
        enum DocC 
        {
            case community(Community)
            case fnv(hash:UInt32)
        }

        var base:Symbol.ID?
        var host:Symbol.ID?
        var docC:DocC?

        init(base:Symbol.ID? = nil, host:Symbol.ID? = nil)
        {
            self.base = base 
            self.host = host 
            self.docC = nil
        }

        func disambiguate(_ selection:inout _Selection<Branch.Composite>, context:Package.Context) 
        {
            if  case .many(let composites) = selection,
                let filtered:_Selection<Branch.Composite> = .init(composites.filter 
                { 
                    self.matches($0, context: context) 
                })
            {
                selection = filtered
            }
        }
        // in general, we cannot assume anything about the locality of the base or host 
        // components in a synthetic composite.
        func matches(_ composite:Branch.Composite, context:Package.Context) -> Bool 
        {
            if  let host:Branch.Position<Symbol> = composite.host
            {
                if  let id:Symbol.ID = self.host, 
                    let host:Symbol = context.load(host), 
                        host.id != id 
                {
                    return false 
                }
            }
            else 
            {
                guard case nil = self.host 
                else 
                {
                    return false 
                }
            }
            if  let id:Symbol.ID = self.base, 
                let base:Symbol = context.load(composite.base)
            {
                return base.id == id 
            }
            else 
            {
                return true
            }
        }
    }
    struct Nationality 
    {
        let id:Package.ID 
        let version:Version.Selector?
    }

    enum Orientation:Unicode.Scalar
    {
        case gay        = "."
        case straight   = "/"
    }

    private(set)
    var path:Path, 
        nationality:Nationality?,
        disambiguator:Disambiguator

    var startIndex:Path.Index
    {
        self.path.startIndex
    }
    var endIndex:Path.Index
    {
        self.path.endIndex
    }
    subscript(index:Path.Index) -> String
    {
        _read 
        {
            yield self.path[index].string
        }
    }

    // init(revealing path:some Collection<some StringProtocol>, base:Symbol.ID?, host:Symbol.ID?) 
    //     throws 
    // {
    //     self.init(path: try Path.init(path).revealed, base: base, host: host)
    // }
    // init(path:some Collection<some StringProtocol>, base:Symbol.ID?, host:Symbol.ID?) 
    //     throws 
    // {
    //     self.init(path: try .init(path), base: base, host: host)
    // }
    private 
    init(path:Path, nationality:Nationality?, disambiguator:Disambiguator) 
    {
        self.path = path
        self.nationality = nationality
        self.disambiguator = disambiguator
    }
    init(path:Path) 
    {
        self.init(path: path, nationality: nil, disambiguator: .init())
    }

    var first:String
    {
        _read 
        {
            yield self.path.first.string
        }
    }
    var revealed:Self 
    {
        .init(path: self.path.revealed, 
            nationality: self.nationality,
            disambiguator: self.disambiguator)
    }
    var suffix:Self?
    {
        self.path.suffix.map 
        { 
            .init(path: $0, nationality: self.nationality, disambiguator: self.disambiguator) 
        }
    }
    var outed:Self?
    {
        self.path.outed.map 
        { 
            .init(path: $0, nationality: self.nationality, disambiguator: self.disambiguator) 
        }
    }

    /// Parses and removes the DocC suffix from the end of this symbollink. 
    /// 
    /// This operation may invalidate links to a package or an article. 
    /// Only call this if you are sure this symbollink is supposed to point 
    /// to a symbol.
    mutating 
    func disambiguate() 
    {
        if  let disambiguator:Disambiguator.DocC = 
                self.path.last.removeDocCFragment(global: self.path.count == 1)
        {
            self.disambiguator.docC = disambiguator
        }
    }
    func disambiguated() -> Self 
    {
        var link:Self = self 
            link.disambiguate() 
        return link
    }
}

extension _SymbolLink 
{
    init?(_ global:GlobalLink) throws 
    {
        guard let path:Path = try .init(components: global, fold: global.fold)
        else 
        {
            return nil 
        }
        self.init(path: path, 
            nationality: global.nationality, 
            disambiguator: .init(base: global.base, host: global.host))
    }
    init?(_ uri:URI) throws 
    {
        guard let path:Path = try .init(uri.path)
        else 
        {
            return nil 
        }
        self.init(path: path)
        if let query:[URI.Parameter] = uri.query 
        {
            self.update(with: query)
        }
    }
    mutating 
    func update(with parameters:some Sequence<URI.Parameter>)
    {
        for (key, value):(String, String) in parameters 
        {
            // slightly different from the parser in `PluralReference.swift`
            if  let key:GlobalLink.Parameter = .init(rawValue: key), 
                let id:Symbol.ID = try? USR.Rule<String.Index>.OpaqueName.parse(value.utf8)
            {
                switch key 
                {
                case .host: self.disambiguator.host = id
                case .base: self.disambiguator.base = id
                case .culture: continue
                }
            }
        }
    }
}