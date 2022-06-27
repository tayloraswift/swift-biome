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
        fileprivate 
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
        struct Query 
        {
            static 
            let base:String = "overload", 
                host:String = "self", 
                lens:String = "from"
            
            var base:ID?
            var host:ID?
            var lens:(culture:Package.ID, version:MaskedVersion?)?
            
            init() 
            {
                self.base = nil 
                self.host = nil
                self.lens = nil 
            }
            init(_ parameters:[URI.Parameter]) throws 
            {
                self.init()
                try self.update(with: parameters)
            }
            mutating 
            func update(with parameters:[URI.Parameter]) throws 
            {
                for (key, value):(String, String) in parameters 
                {
                    switch key
                    {
                    case Self.lens:
                        // either 'from=swift-foo' or 'from=swift-foo/0.1.2'. 
                        // we do not tolerate missing slashes
                        let components:[Substring] = value.split(separator: "/")
                        guard let first:Substring = components.first
                        else 
                        {
                            continue  
                        }
                        let id:Package.ID = .init(first)
                        if  let second:Substring = components.dropFirst().first, 
                            let version:MaskedVersion = try? Grammar.parse(second.unicodeScalars, 
                                as: MaskedVersion.Rule<String.Index>.self)
                        {
                            self.lens = (id, version)
                        }
                        else 
                        {
                            self.lens = (id, nil)
                        }
                    
                    case Self.host:
                        // if the mangled name contained a colon ('SymbolGraphGen style'), 
                        // the parsing rule will remove it.
                        self.host  = try Grammar.parse(value.utf8, as: USR.Rule<String.Index>.OpaqueName.self)
                    
                    case Self.base: 
                        switch         try Grammar.parse(value.utf8, as: USR.Rule<String.Index>.self) 
                        {
                        case .natural(let base):
                            self.base = base
                        
                        case .synthesized(from: let base, for: let host):
                            // this is supported for backwards-compatibility, 
                            // but the `::SYNTHESIZED::` infix is deprecated, 
                            // so this will end up causing a redirect 
                            self.host = host
                            self.base = base 
                        }

                    default: 
                        continue  
                    }
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
            if path.fold != path.components.startIndex 
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
// parsing rules 
extension Symbol.Link 
{
    fileprivate 
    enum Rule<Location>
    {
        typealias Terminal = Unicode.Scalar
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
extension Symbol.Link.Rule 
{
    //  Arguments ::= '(' ( IdentifierBase ':' ) + ')'
    private 
    enum Arguments:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws 
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            try input.parse(as: Encoding.ParenthesisLeft.self)
            try input.parse(as: IdentifierBase.self)
            try input.parse(as: Encoding.Colon.self)
            // note: parse as tuple, otherwise we may accidentally accept something 
            // like 'foo(bar:baz)', which is missing the trailing colon
            while let _:(Void, Void) = try? input.parse(as: (IdentifierBase, Encoding.Colon).self)
            {
            }
            try input.parse(as: Encoding.ParenthesisRight.self)
        }
    }
    
    private 
    enum IdentifierFirst:TerminalRule 
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Void
        static 
        func parse(terminal:Terminal) -> Void? 
        {
            switch terminal 
            {
            case    "a" ... "z", 
                    "A" ... "Z",
                    "_", 

                    "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}", 
                    "\u{00B2}" ... "\u{00B5}", "\u{00B7}" ... "\u{00BA}",

                    "\u{00BC}" ... "\u{00BE}", "\u{00C0}" ... "\u{00D6}", 
                    "\u{00D8}" ... "\u{00F6}", "\u{00F8}" ... "\u{00FF}",

                    "\u{0100}" ... "\u{02FF}", "\u{0370}" ... "\u{167F}", "\u{1681}" ... "\u{180D}", "\u{180F}" ... "\u{1DBF}", 

                    "\u{1E00}" ... "\u{1FFF}", 

                    "\u{200B}" ... "\u{200D}", "\u{202A}" ... "\u{202E}", "\u{203F}" ... "\u{2040}", "\u{2054}", "\u{2060}" ... "\u{206F}",

                    "\u{2070}" ... "\u{20CF}", "\u{2100}" ... "\u{218F}", "\u{2460}" ... "\u{24FF}", "\u{2776}" ... "\u{2793}",

                    "\u{2C00}" ... "\u{2DFF}", "\u{2E80}" ... "\u{2FFF}",

                    "\u{3004}" ... "\u{3007}", "\u{3021}" ... "\u{302F}", "\u{3031}" ... "\u{303F}", "\u{3040}" ... "\u{D7FF}",

                    "\u{F900}" ... "\u{FD3D}", "\u{FD40}" ... "\u{FDCF}", "\u{FDF0}" ... "\u{FE1F}", "\u{FE30}" ... "\u{FE44}", 

                    "\u{FE47}" ... "\u{FFFD}", 

                    "\u{10000}" ... "\u{1FFFD}", "\u{20000}" ... "\u{2FFFD}", "\u{30000}" ... "\u{3FFFD}", "\u{40000}" ... "\u{4FFFD}", 

                    "\u{50000}" ... "\u{5FFFD}", "\u{60000}" ... "\u{6FFFD}", "\u{70000}" ... "\u{7FFFD}", "\u{80000}" ... "\u{8FFFD}", 

                    "\u{90000}" ... "\u{9FFFD}", "\u{A0000}" ... "\u{AFFFD}", "\u{B0000}" ... "\u{BFFFD}", "\u{C0000}" ... "\u{CFFFD}", 

                    "\u{D0000}" ... "\u{DFFFD}", "\u{E0000}" ... "\u{EFFFD}":
                return ()
            default:
                return nil
            }
        }
    }
    private 
    enum IdentifierNext:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Void
        static 
        func parse(terminal:Terminal) -> Void?
        {
            switch terminal 
            {
            case    "0" ... "9", 
                    "\u{0300}" ... "\u{036F}", 
                    "\u{1DC0}" ... "\u{1DFF}", 
                    "\u{20D0}" ... "\u{20FF}", 
                    "\u{FE20}" ... "\u{FE2F}":
                return ()
            default:
                return IdentifierFirst.parse(terminal: terminal) 
            }
        }
    }
    //  IdentifierBase ::= IdentifierFirst IdentifierNext *
    private 
    enum IdentifierBase:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws 
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            try input.parse(as: IdentifierFirst.self)
            input.parse(as: IdentifierNext.self, in: Void.self)
        }
    }
    //  IdentifierLeaf ::= IdentifierBase Arguments ? 
    private 
    enum IdentifierLeaf:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws 
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            try input.parse(as: IdentifierBase.self)
            input.parse(as: Arguments?.self)
        }
    }
    
    private 
    enum DotlessOperatorFirst:TerminalRule 
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Void
        static 
        func parse(terminal:Terminal) -> Void?
        {
            switch terminal 
            {
            case    "/", "=", "-", "+", "!", "*", "%", "<", ">", "&", "|", "^", "~", "?",
                    "\u{00A1}" ... "\u{00A7}",
                    "\u{00A9}", "\u{00AB}",
                    "\u{00AC}", "\u{00AE}",
                    "\u{00B0}" ... "\u{00B1}",
                    "\u{00B6}", "\u{00BB}", "\u{00BF}", "\u{00D7}", "\u{00F7}",
                    "\u{2016}" ... "\u{2017}",
                    "\u{2020}" ... "\u{2027}",
                    "\u{2030}" ... "\u{203E}",
                    "\u{2041}" ... "\u{2053}",
                    "\u{2055}" ... "\u{205E}",
                    "\u{2190}" ... "\u{23FF}",
                    "\u{2500}" ... "\u{2775}",
                    "\u{2794}" ... "\u{2BFF}",
                    "\u{2E00}" ... "\u{2E7F}",
                    "\u{3001}" ... "\u{3003}",
                    "\u{3008}" ... "\u{3020}",
                    "\u{3030}":
                return ()
            default:
                return nil
            }
        }
    }
    private 
    enum DotlessOperatorNext:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Void
        static 
        func parse(terminal:Terminal) -> Void?
        {
            switch terminal 
            {
            case    "\u{0300}" ... "\u{036F}",
                    "\u{1DC0}" ... "\u{1DFF}",
                    "\u{20D0}" ... "\u{20FF}",
                    "\u{FE00}" ... "\u{FE0F}",
                    "\u{FE20}" ... "\u{FE2F}",
                    "\u{E0100}" ... "\u{E01EF}":
                return ()
            default:
                return DotlessOperatorFirst.parse(terminal: terminal) 
            }
        }
    }
    //  DotlessOperatorLeaf ::= DotlessOperatorFirst DotlessOperatorNext * Arguments 
    private 
    enum DotlessOperatorLeaf:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws 
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            try input.parse(as: DotlessOperatorFirst.self)
                input.parse(as: DotlessOperatorNext.self, in: Void.self)
            try input.parse(as: Arguments.self)
        }
    }
    private 
    enum DottedOperatorNext:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Void
        static 
        func parse(terminal:Terminal) -> Void?
        {
            switch terminal 
            {
            case ".":
                return ()
            default:
                return DotlessOperatorFirst.parse(terminal: terminal) ?? 
                        DotlessOperatorNext.parse(terminal: terminal)
            }
        }
    }
    //  Leaf  ::= IdentifierLeaf
    //          | DotlessOperatorLeaf
    //          | '.' DottedOperatorNext + Arguments 
    private 
    enum Leaf:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            guard   case nil = input.parse(as: IdentifierLeaf?.self), 
                    case nil = input.parse(as: DotlessOperatorLeaf?.self)
            else 
            {
                return 
            }
            try input.parse(as: Encoding.Period.self)
            try input.parse(as: DottedOperatorNext.self)
                input.parse(as: DottedOperatorNext.self, in: Void.self)
            try input.parse(as: Arguments.self)
        }
    }
    
    //  LexicalComponent  ::= IdentifierBase   '.' Leaf 
    //                      | IdentifierBase Arguments
    //                      | IdentifierBase ( '-' . * ) ?
    //                      |   '.' IdentifierLeaf
    //                      | ( '.' DottedOperatorNext + Arguments )
    //                      | DotlessOperatorLeaf
    //                      | UInt   '-' UInt   '-' UInt
    //                      | UInt ( '.' UInt ( '.' UInt ( '.' UInt ) ? ) ? ) ?
    enum Component:ParsingRule
    {
        typealias Terminal = Unicode.Scalar
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> Symbol.Link.ComponentSegmentation<Location>
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
        {
            let start:Location = input.index 
            guard case nil = input.parse(as: IdentifierBase?.self)
            else 
            {
                let end:Location = input.index 
                if let _:Void = input.parse(as: Encoding.Period?.self)
                {
                    //  /foo.bar          -> ['foo', 'bar']
                    //  /foo.bar(baz:)    -> ['foo', 'bar(baz:)']
                    //  /foo.<(_:_:)      -> ['foo',   '<(_:_:)']
                    //  /foo....(_:_:)    -> ['foo', '...(_:_:)']
                    //  note: the leading dot is *not* part of the operator.
                    let next:Location = input.index 
                    try input.parse(as: Leaf.self)
                    return .reveal(big: end, little: next)
                }
                // since the hyphen-based suffix can be empty (and therefore always succeeds)
                else if let _:Void = input.parse(as: Arguments?.self)
                {
                    //  docc compatibility form. it’s exactly the same as prefixing 
                    //  the identifier with a '.', and therefore implies an empty 
                    //  semantic component right before it.
                    //  /bar(baz:) -> ['', 'bar(baz:)']
                    return .little(start)
                }
                else if let _:Void = input.parse(as: Encoding.Hyphen?.self)
                {
                    //  a package name, like '/swift-grammar', or a docc disambiguator
                    //  like '/indices-ckjvzkc' or '/indices-swift.var'.
                    //  after encountering a hyphen, there are no restrictions 
                    //  on what characters can appear through the end of the component.
                    input.parse(as: Terminal.self, in: Void.self)
                    return .opaque(end)
                }
                else 
                {
                    return .big
                }
            }
            guard case nil = input.parse(as: Encoding.Period?.self)
            else
            {
                let next:Location = input.index
                if let _:Void = input.parse(as: IdentifierLeaf?.self)
                {
                    //  /.bar       -> ['', 'bar']
                    //  /.bar(baz:) -> ['', 'bar(baz:)']
                    return .little(next)
                }
                else 
                {
                    //  /...(_:_:)  -> ['', '...(_:_:)']
                    //  note: the leading dot is *part* of the operator, for 
                    //  docc compatibility purposes.
                    try input.parse(as: DottedOperatorNext.self)
                        input.parse(as: DottedOperatorNext.self, in: Void.self)
                    try input.parse(as: Arguments.self)
                    return .little(start)
                }
            }
            //  /<(_:_:)  -> ['', '<(_:_:)']
            try input.parse(as: DotlessOperatorLeaf.self)
            return .little(start)
        }
    }
}
