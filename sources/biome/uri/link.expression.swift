import Grammar 

extension Link 
{
    struct Expression
    {
        private(set)
        var reference:Reference<[Component]>, 
            visible:Int
        
        init(absolute string:String) throws 
        {
            try self.init(normalizing: try .init(absolute: string))
        }
        init(relative string:String) throws 
        {
            try self.init(normalizing: try .init(relative: string))
        }
        
        init(normalizing uri:URI) throws
        {
            // ii. lexical normalization 
            //
            // ['', 'foo', 'bar', < nil >, 'bax.qux', < Self >, '', 'baz.bar', '.Foo', '..', '', ''] becomes 
            // [    'foo', 'bar',                                   'baz.bar', '.Foo', '..']
            //                                                      ^~~~~~~~~~~~~~~~~~~~~~~
            //                                                      (visible = 3)
            //  if `Self` components would erase past the beginning of the components list, 
            //  the extra `Self` components are ignored.
            //  redirects generated from this step are PERMANENT. 
            //  paths containing `nil` and empty components always generate redirects.
            //  however, the presence and location of an empty component can be meaningful 
            //  in a symbollink.    
            var components:[String] = []
                components.reserveCapacity(uri.path.count)
            var fold:Int = components.endIndex
            for vector:URI.Vector? in uri.path
            {
                switch vector 
                {
                case .pop?:
                    let _:String? = components.popLast()
                    fallthrough
                case nil: 
                    fold = components.endIndex
                case .push(let component): 
                    components.append(component)
                }
            }
            // iii. semantic segmentation 
            //
            // [     'foo',       'bar',       'baz.bar',                     '.Foo',          '..'] becomes
            // [.big("foo"), .big("bar"), .big("baz"), .little("bar"), .little("Foo"), .little("..")] 
            //                                                                         ^~~~~~~~~~~~~~~
            //                                                                          (visible = 1)
            self.reference = .init(path: [])
            self.visible = 0
            for (index, component):(Int, String) in zip(components.indices, components)
            {
                let appended:Int 
                switch try Grammar.parse(component.unicodeScalars, as: Rule<String.Index>.Component.self)
                {
                case .opaque(let hyphen): 
                    self.reference.path.append(.identifier(component, hyphen: hyphen))
                    self.reference.orientation = .straight 
                    appended = 1
                case .big:
                    self.reference.path.append(.identifier(component))
                    self.reference.orientation = .straight 
                    appended = 1
                
                case .little                      (let start):
                    // an isolated little-component implies an empty big-predecessor, 
                    // and therefore resets the visibility counter
                    self.visible = 0
                    self.reference.path.append(.identifier(String.init(component[start...])))
                    self.reference.orientation = .gay 
                    appended = 1
                
                case .reveal(big: let end, little: let start):
                    self.reference.path.append(.identifier(String.init(component[..<end])))
                    self.reference.path.append(.identifier(String.init(component[start...])))
                    self.reference.orientation = .gay 
                    appended = 2
                    
                case .version(let version):
                    self.reference.path.append(.version(version))
                    self.reference.orientation = .straight 
                    appended = 1
                }
                if fold <= index 
                {
                    self.visible += appended
                }
            }
            if let query:[URI.Parameter] = uri.query 
            {
                try self.reference.query.update(normalizing: query)
            }
        }
    }
    
    fileprivate 
    enum ComponentSegmentation<Location> where Location:Comparable
    {
        case opaque(Location) // end index
        case version(Version)
        case big
        case little(Location) // start index 
        case reveal(big:Location, little:Location) // end index, start index
    }
}
// parsing rules 
extension Link 
{
    fileprivate 
    enum Rule<Location>
    {
        typealias Terminal = Unicode.Scalar
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
extension Link.Rule 
{
    private 
    typealias Integer = Grammar.UnsignedIntegerLiteral<Grammar.DecimalDigitScalar<Location, Int>>
    
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
    
    private 
    enum ToolchainOrdinal:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = Unicode.Scalar
        static 
        func parse(terminal:Terminal) -> Unicode.Scalar?
        {
            switch terminal 
            {
            case "a" ... "z":   return terminal 
            //case "A" ... "Z":   return terminal.lowercased()
            default:            return nil
            }
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
            throws -> Link.ComponentSegmentation<Location>
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
            guard case nil = input.parse(as: DotlessOperatorLeaf?.self)
            else 
            {
                //  /<(_:_:)  -> ['', '<(_:_:)']
                return .little(start)
            }
            
            let first:Int = try input.parse(as: Integer.self)
            guard case nil = input.parse(as: Encoding.Hyphen?.self)
            else 
            {
                // parse a date 
                let month:Int = try input.parse(as: Integer.self)
                try input.parse(as: Encoding.Hyphen.self)
                let day:Int = try input.parse(as: Integer.self)
                try input.parse(as: Encoding.Hyphen.self)
                let letter:Unicode.Scalar = try input.parse(as: ToolchainOrdinal.self)
                return .version(.date(year: first, month: month, day: day, letter: letter))
            }
            // parse a x.y.z.w semantic version. the w component is 
            // a documentation version, which is a sub-patch increment
            guard let minor:Int = input.parse(as: Integer?.self)
            else 
            {
                return .version(.tag(first, nil))
            }
            guard let patch:Int = input.parse(as: Integer?.self)
            else 
            {
                return .version(.tag(first, (minor, nil)))
            }
            guard let edition:Int = input.parse(as: Integer?.self)
            else 
            {
                return .version(.tag(first, (minor, (patch, nil))))
            }
            return .version(.tag(first, (minor, (patch, edition))))
        }
    }
}
