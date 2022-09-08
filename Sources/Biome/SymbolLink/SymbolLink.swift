import SymbolGraphs
import URI

struct _SymbolLink:RandomAccessCollection
{
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
    enum Orientation:Unicode.Scalar
    {
        case gay        = "."
        case straight   = "/"
    }

    private(set)
    var disambiguator:Disambiguator,
        orientation:Orientation
    private
    var path:[Component]
    
    private(set)
    var startIndex:Int
    var endIndex:Int 
    {
        self.path.endIndex
    }
    subscript(index:Int) -> Component
    {
        _read 
        {
            yield self.path[index]
        }
    }
    
    func prefix(prepending prefix:[String]) -> [String]
    {
        prefix.isEmpty ? self.dropLast().map(\.string) : 
                prefix + self.dropLast().lazy.map(\.string)
    }
    var suffix:Self?
    {
        var suffix:Self = self 
            suffix.startIndex += 1
        return suffix.isEmpty ? nil : suffix 
    }
    
    var revealed:Self 
    {
        var revealed:Self = self 
            revealed.startIndex = revealed.path.startIndex 
        return revealed
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

    init(path:some Collection<some StringProtocol>, base:Symbol.ID?, host:Symbol.ID?) throws 
    {
        try self.init(path: (path, path.startIndex), base: base, host: host)
    }
    init<Path>(path:(components:Path, fold:Path.Index), base:Symbol.ID?, host:Symbol.ID?) 
        throws
        where Path:Collection, Path.Element:StringProtocol
    {
        // iii. semantic segmentation 
        //
        // [     'foo',       'bar',       'baz.bar',                     '.Foo',          '..'] becomes
        // [.big("foo"), .big("bar"), .big("baz"), .little("bar"), .little("Foo"), .little("..")] 
        //                                                                         ^~~~~~~~~~~~~~~
        //                                                                          (visible = 1)
        self.disambiguator = .init(base: base, host: host)
        self.orientation = .straight
        self.path = []
        self.path.reserveCapacity(path.components.underestimatedCount)
        self.startIndex = self.path.startIndex 
        // it is valid to pass an index for `fold` that is outside the bounds of 
        // the components collection!
        if path.components.startIndex < path.fold
        {
            try self.append(components: path.components[..<path.fold])
            self.startIndex = self.path.endIndex
            try self.append(components: path.components[path.fold...])
        }
        else 
        {
            try self.append(components: path.components)
        }
    }

    mutating 
    func disambiguate() 
    {
        if  let last:Int = self.path.indices.last, 
            let disambiguator:Disambiguator.DocC = 
                self.path[last].removeDocCFragment(global: self.count == 1)
        {
            self.disambiguator.docC = disambiguator
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
                self.path.append(.init(String.init(component), hyphen: hyphen))
                self.orientation = .straight 
            case .big:
                self.path.append(.init(String.init(component)))
                self.orientation = .straight 
            
            case .little                      (let start):
                // an isolated little-component implies an empty big-predecessor, 
                // and therefore resets the visibility counter
                self.startIndex = self.path.endIndex
                self.path.append(.init(String.init(component[start...])))
                self.orientation = .gay 
            
            case .reveal(big: let end, little: let start):
                self.path.append(.init(String.init(component[..<end])))
                self.path.append(.init(String.init(component[start...])))
                self.orientation = .gay 
            }
        }
    }
}
