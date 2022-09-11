import SymbolGraphs
import URI

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

        init(_ components:some Collection<some StringProtocol>) throws 
        {
            try self.init(components: components, fold: components.startIndex)
        }
        init(_ vectors:some Collection<URI.Vector?>) throws 
        {
            let (components, fold):([String], Int) = vectors.normalized 
            try self.init(components: components, fold: fold)
        }
        init<Path>(components:Path, fold:Path.Index) throws
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
            return suffix.isEmpty ? nil : suffix 
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

        let base:Symbol.ID?
        let host:Symbol.ID?
        var docC:DocC?

        init(base:Symbol.ID?, host:Symbol.ID?)
        {
            self.base = base 
            self.host = host 
            self.docC = nil
        }
    }


    enum Orientation:Unicode.Scalar
    {
        case gay        = "."
        case straight   = "/"
    }

    private(set)
    var path:Path, 
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
    
    init(revealing path:some Collection<some StringProtocol>, base:Symbol.ID?, host:Symbol.ID?) 
        throws 
    {
        self.init(path: try Path.init(path).revealed, base: base, host: host)
    }
    init(path:some Collection<some StringProtocol>, base:Symbol.ID?, host:Symbol.ID?) 
        throws 
    {
        self.init(path: try .init(path), base: base, host: host)
    }
    init(path:Path, base:Symbol.ID?, host:Symbol.ID?) 
    {
        self.init(path: path, disambiguator: .init(base: base, host: host))
    }
    private 
    init(path:Path, disambiguator:Disambiguator) 
    {
        self.path = path
        self.disambiguator = disambiguator
    }

    var revealed:Self 
    {
        .init(path: self.path.revealed, disambiguator: self.disambiguator)
    }
    var suffix:Self?
    {
        self.path.suffix.map { .init(path: $0, disambiguator: self.disambiguator) }
    }
    var outed:Self?
    {
        self.path.outed.map { .init(path: $0, disambiguator: self.disambiguator) }
    }

    mutating 
    func disambiguate() 
    {
        if  let last:Int = self.path.indices.last, 
            let disambiguator:Disambiguator.DocC = 
                self.path[last].removeDocCFragment(global: self.path.count == 1)
        {
            self.disambiguator.docC = disambiguator
        }
    }
}
