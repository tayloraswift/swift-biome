import Grammar 

extension Symbol 
{
    struct Disambiguator 
    {
        let host:ID?
        let base:ID?
        let suffix:Link.Suffix?
    }
    struct Link:RandomAccessCollection
    {
        enum ComponentSegmentation<Location> where Location:Comparable
        {
            case opaque(Location) // end index
            case big
            case little(Location) // start index 
            case reveal(big:Location, little:Location) // end index, start index
        }
        // warning: do not make ``Equatable``, unless we enforce the correctness 
        // of the `hyphen` field!
        struct Component 
        {
            let string:String 
            let hyphen:String.Index?
            
            init(_ string:String, hyphen:String.Index? = nil)
            {
                self.string = string 
                self.hyphen = hyphen
            }
            
            var suffix:Suffix?
            {
                self.hyphen.flatMap { .init(self.string[$0...].dropFirst()) }
            }
        }
        enum Orientation:Unicode.Scalar
        {
            case gay        = "."
            case straight   = "/"
        }
        enum Suffix 
        {
            case color(Color)
            case fnv(hash:UInt32)
            
            init?<S>(_ string:S) where S:StringProtocol 
            {
                // will never collide with symbol colors, since they always contain 
                // a period ('.')
                // https://github.com/apple/swift-docc/blob/d94139a5e64e9ecf158214b1cded2a2880fc1b02/Sources/SwiftDocC/Utility/FoundationExtensions/String%2BHashing.swift
                if let hash:UInt32 = .init(string, radix: 36)
                {
                    self = .fnv(hash: hash)
                }
                else if let color:Color = .init(rawValue: String.init(string))
                {
                    self = .color(color)
                }
                else 
                {
                    return nil
                }
            }
        }
        
        private
        var path:[Component]
        private(set)
        var query:Query,
            orientation:Orientation
        
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
            .init(path: self.path, query: self.query, orientation: self.orientation)
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
        var disambiguator:Disambiguator 
        {
            .init(
                host: self.query.host, 
                base: self.query.base, 
                suffix: self.path.last?.suffix)
        }
        
        private 
        init(path:[Component], query:Query, orientation:Orientation = .straight) 
        {
            self.startIndex = path.startIndex 
            self.path = path 
            self.query = query 
            self.orientation = orientation
        }
        init<Path>(path:Path, query:[URI.Parameter]) 
            throws
            where Path:Collection, Path.Element:StringProtocol
        {
            try self.init(path: (path, path.startIndex), query: query)
        }
        init<Path>(path:(components:Path, fold:Path.Index), query:[URI.Parameter]) 
            throws
            where Path:Collection, Path.Element:StringProtocol
        {
            // iii. semantic segmentation 
            //
            // [     'foo',       'bar',       'baz.bar',                     '.Foo',          '..'] becomes
            // [.big("foo"), .big("bar"), .big("baz"), .little("bar"), .little("Foo"), .little("..")] 
            //                                                                         ^~~~~~~~~~~~~~~
            //                                                                          (visible = 1)
            self.init(path: [], query: try .init(query))
            self.path.reserveCapacity(path.components.underestimatedCount)
            // it is valid to pass an index for `fold` that is outside the bounds of 
            // the components collection!
            if path.components.startIndex < path.fold
            {
                try self.append(components: path.components[..<path.fold])
                self.startIndex = self.path.endIndex
            }
            try self.append(components: path.components[path.fold...])
        }
        mutating 
        func append<Path>(components:Path) throws 
            where Path:Sequence, Path.Element:StringProtocol 
        {
            for component:Path.Element in components
            {
                switch try Grammar.parse(component.unicodeScalars, 
                    as: Rule<String.Index>.Component.self)
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
}
