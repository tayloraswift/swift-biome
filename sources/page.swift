final 
class Page 
{
    enum Label 
    {
        case framework 
        
        case enumeration 
        case genericEnumeration 
        case structure 
        case genericStructure 
        case `class`
        case genericClass 
        case `protocol`
        case `typealias`
        case genericTypealias
        
        case enumerationCase
        case initializer
        case genericInitializer
        case staticMethod 
        case genericStaticMethod 
        case instanceMethod 
        case genericInstanceMethod 
        case staticProperty
        case instanceProperty
        case `associatedtype`
        case `subscript` 
    }
    
    enum Link:Equatable
    {
        case unresolved(path:[String])
        case resolved(url:String)
        case apple(url:String)
        
        static 
        func appleify(_ path:[String]) -> Self 
        {
            .apple(url: "https://developer.apple.com/documentation/\(path.map{ $0.lowercased() }.joined(separator: "/"))")
        }
        
        static 
        let metatype:Self = .apple(url: "https://docs.swift.org/swift-book/ReferenceManual/Types.html#ID455")
        
        static 
        func link<T>(_ components:[(String, T)]) -> [(component:(String, T), link:Link)]
        {
            let scan:[(component:(String, T), accumulated:[String])] = components.enumerated().map 
            {
                (($0.1.0, $0.1.1), components.prefix($0.0 + 1).map(\.0))
            }
            
            let link:[(component:(String, T), link:Link)] 
            // apple links 
            if scan.first?.component.0 == "Swift" 
            {
                link = scan.dropFirst().map 
                {
                    ($0.component, .appleify($0.accumulated))
                }
            } 
            else 
            {
                link = scan.map 
                {
                    ($0.component, .unresolved(path: $0.accumulated))
                }
            }
            // metatypes 
            if let (last, _):((String, T), Link) = link.last, 
                last.0 == "Type" 
            {
                return link.dropLast() + [(last, Self.metatype)]
            }
            else 
            {
                return link
            }
        }
    }
    
    enum Declaration 
    {
        enum Token:Equatable
        {
            case whitespace 
            case breakableWhitespace
            case keyword(String)
            case identifier(String)
            case type(String, Link)
            case typePunctuation(String, Link)
            case punctuation(String)
        }
        
        static 
        func tokenize(_ identifiers:[String]) -> [Token]
        {
            return .init(Link.link(identifiers.map{ ($0, ()) }).map 
            {
                [.type($0.component.0, $0.link)]
            }.joined(separator: [.punctuation(".")]))
        }
        
        static 
        func tokenize(_ type:Grammar.SwiftType, locals:Set<String> = []) -> [Token] 
        {
            switch type 
            {
            case .named(let identifiers):
                if      identifiers.count           == 2, 
                        identifiers[0].identifier   == "Swift",
                        identifiers[0].generics.isEmpty
                {
                    if      identifiers[1].identifier       == "Optional", 
                            identifiers[1].generics.count   == 1
                    {
                        let element:Grammar.SwiftType   = identifiers[1].generics[0]
                        let link:Link                   = .appleify(["Swift", "Optional"])
                        var tokens:[Token] = []
                        tokens.append(contentsOf: Self.tokenize(element, locals: locals))
                        tokens.append(.typePunctuation("?", link))
                        return tokens 
                    }
                    else if identifiers[1].identifier       == "Array", 
                            identifiers[1].generics.count   == 1
                    {
                        let element:Grammar.SwiftType   = identifiers[1].generics[0]
                        let link:Link                   = .appleify(["Swift", "Array"])
                        var tokens:[Token] = []
                        tokens.append(.typePunctuation("[", link))
                        tokens.append(contentsOf: Self.tokenize(element, locals: locals))
                        tokens.append(.typePunctuation("]", link))
                        return tokens 
                    }
                    else if identifiers[1].identifier       == "Dictionary", 
                            identifiers[1].generics.count   == 2
                    {
                        let key:Grammar.SwiftType   = identifiers[1].generics[0],
                            value:Grammar.SwiftType = identifiers[1].generics[1]
                        let link:Link               = .appleify(["Swift", "Dictionary"])
                        var tokens:[Token] = []
                        tokens.append(.typePunctuation("[", link))
                        tokens.append(contentsOf: Self.tokenize(key, locals: locals))
                        tokens.append(.typePunctuation(":", link))
                        tokens.append(.whitespace)
                        tokens.append(contentsOf: Self.tokenize(value, locals: locals))
                        tokens.append(.typePunctuation("]", link))
                        return tokens 
                    }
                }
                else if let first:String = identifiers.first?.identifier, 
                    locals.contains(first), 
                    identifiers.allSatisfy(\.generics.isEmpty) 
                {
                    if identifiers.count == 2, identifiers[1].identifier == "Type"
                    {
                        return [.identifier(identifiers[0].identifier), .punctuation("."), .type("Type", Link.metatype)]
                    }
                    else 
                    {
                        return .init(identifiers.map{ [.identifier($0.identifier)] }.joined(separator: [.punctuation(".")]))
                    }
                }
                
                return .init(Link.link(identifiers.map{ ($0.identifier, $0.generics) }).map 
                {
                    (element:(component:(identifier:String, generics:[Grammar.SwiftType]), link:Link)) -> [Token] in 
                    var tokens:[Token] = [.type(element.component.identifier, element.link)]
                    if !element.component.generics.isEmpty
                    {
                        tokens.append(.punctuation("<"))
                        tokens.append(contentsOf: element.component.generics.map{ Self.tokenize($0, locals: locals) }
                            .joined(separator: [.punctuation(","), .breakableWhitespace]))
                        tokens.append(.punctuation(">"))
                    }
                    return tokens
                }.joined(separator: [.punctuation(".")]))
            
            case .compound(let elements):
                var tokens:[Token] = []
                tokens.append(.punctuation("("))
                tokens.append(contentsOf: elements.map 
                {
                    (element:Grammar.LabeledType) -> [Token] in
                    var tokens:[Token]  = []
                    if let label:String = element.label
                    {
                        tokens.append(.identifier(label))
                        tokens.append(.punctuation(":"))
                    }
                    tokens.append(contentsOf: Self.tokenize(element.type, locals: locals))
                    return tokens 
                }.joined(separator: [.punctuation(","), .breakableWhitespace]))
                tokens.append(.punctuation(")"))
                return tokens
            
            case .function(let type):
                var tokens:[Token] = []
                for attribute:Grammar.Attribute in type.attributes
                {
                    tokens.append(.keyword("\(attribute)"))
                    tokens.append(.breakableWhitespace)
                }
                tokens.append(.punctuation("("))
                tokens.append(contentsOf: type.parameters.map 
                {
                    (parameter:Grammar.FunctionParameter) -> [Token] in
                    var tokens:[Token]  = []
                    for attribute:Grammar.Attribute in parameter.attributes
                    {
                        tokens.append(.keyword("\(attribute)"))
                        tokens.append(.whitespace)
                    }
                    if parameter.inout 
                    {
                        tokens.append(.keyword("inout"))
                        tokens.append(.whitespace)
                    }
                    tokens.append(contentsOf: Self.tokenize(parameter.type, locals: locals))
                    return tokens 
                }.joined(separator: [.punctuation(","), .breakableWhitespace]))
                tokens.append(.punctuation(")"))
                tokens.append(.breakableWhitespace)
                if type.throws
                {
                    tokens.append(.keyword("throws"))
                    tokens.append(.breakableWhitespace)
                }
                tokens.append(.keyword("->"))
                tokens.append(.whitespace)
                tokens.append(contentsOf: Self.tokenize(type.return, locals: locals))
                return tokens
            
            case .protocols(let protocols):
                return .init(protocols.map 
                {
                    (identifiers:[String]) -> [Token] in 
                    
                    .init(Link.link(identifiers.map{ ($0, ()) }).map 
                    {
                        (element:(component:(identifier:String, _:Void), link:Link)) -> [Token] in 
                        [.type(element.component.identifier, element.link)]
                    }.joined(separator: [.punctuation(".")]))
                }.joined(separator: [.whitespace, .punctuation("&"), .whitespace]))
            }
        } 
        
        // includes trailing whitespace 
        static 
        func tokenize(_ attributes:[Grammar.AttributeField]) -> [Token] 
        {
            var tokens:[Page.Declaration.Token] = []
            for attribute:Grammar.AttributeField in attributes 
            {
                switch attribute
                {
                case .frozen, .inlinable, .discardableResult, .resultBuilder, .propertyWrapper:
                    tokens.append(.keyword("@\(attribute)"))
                    tokens.append(.breakableWhitespace)
                case .wrapped(let wrapper):
                    tokens.append(.keyword("@"))
                    tokens.append(contentsOf: Self.tokenize(wrapper))
                    tokens.append(.breakableWhitespace)
                case .specialized:
                    break // not implemented 
                }
            }
            return tokens
        }
    }
    
    enum Signature
    {
        enum Token:Equatable
        {
            case whitespace 
            case text(String)
            case punctuation(String)
            case highlight(String)
        }
        
        static 
        func convert(_ declaration:[Declaration.Token]) -> [Token] 
        {
            declaration.map 
            {
                switch $0 
                {
                case    .whitespace, .breakableWhitespace:
                    return .whitespace
                case    .keyword(let text), 
                        .identifier(let text),
                        .type(let text, _):
                    return .text(text)
                case    .typePunctuation(let text, _), 
                        .punctuation(let text):
                    return .punctuation(text)
                }
            }
        }
    }
    
    struct Binding 
    {
        struct Key:Hashable 
        {
            let key:String 
            let rank:Int, 
                order:Int 
            
            init(_ key:String, rank:Int, order:Int) 
            {
                self.key   = key 
                self.rank  = rank
                self.order = order
            }
        }
        
        let urlpattern:(prefix:String, suffix:String)
        let page:Page 
        let locals:Set<String>, 
            keys:Set<Key>
        // default ordering 
        let rank:Int, 
            order:Int
        
        var path:[String] 
        {
            self.page.path 
        }
        
        // needed to uniquify overloaded symbols
        var uniquePath:[String] 
        {
            if let overload:Int = self.page.overload 
            {
                return self.path.dropLast() + ["\(overload)-\(self.path[self.path.endIndex - 1])"]
            }
            else 
            {
                return self.path 
            }
        }
        
        var url:String 
        {
            "\(self.urlpattern.prefix)/\(self.uniquePath.map(Self.escape(url:)).joined(separator: "/"))\(self.urlpattern.suffix)"
        }
        var filepath:String 
        {
            self.uniquePath.joined(separator: "/")
        }
        
        init(_ page:Page, locals:Set<String>, keys:Set<Key>, rank:Int, order:Int, 
            urlpattern:(prefix:String, suffix:String)) 
        {
            self.urlpattern = urlpattern
            self.page       = page 
            self.locals     = locals 
            self.keys       = keys 
            self.rank       = rank 
            self.order      = order
        }
        
        private static 
        func hex(_ value:UInt8) -> UInt8
        {
            if value < 10 
            {
                return 0x30 + value 
            }
            else 
            {
                return 0x37 + value 
            }
        }
        private static 
        func escape(url:String) -> String 
        {
            .init(decoding: url.utf8.flatMap 
            {
                (byte:UInt8) -> [UInt8] in 
                switch byte 
                {
                ///  [0-9]          [A-Z]        [a-z]            '-'   '_'   '~'
                case 0x30 ... 0x39, 0x41 ... 0x5a, 0x61 ... 0x7a, 0x2d, 0x5f, 0x7e:
                    return [byte] 
                default:
                    return [0x25, hex(byte >> 4), hex(byte & 0x0f)]
                }
            }, as: Unicode.ASCII.self)
        }
    }
    
    typealias TopicSymbol   = (signature:[Signature.Token], url:String, blurb:[Markdown.Element], required:[Markdown.Element])
    typealias Topic         = (topic:String, keys:[String], symbols:[TopicSymbol])
    
    let label:Label 
    let name:String //name is not always last component of path 
    let signature:[Signature.Token]
    var declaration:[Declaration.Token] 
    var blurb:[Markdown.Element]
    var discussion:
    (
        parameters:[(name:String, paragraphs:[[Markdown.Element]])], 
        return:[[Markdown.Element]],
        overview:[[Markdown.Element]], 
        required:[Markdown.Element],
        specializations:[Markdown.Element]
    )
    
    var topics:[Topic]
    var breadcrumbs:[(text:String, link:Link)], 
        breadcrumb:String 
    
    var inheritances:[[String]] 
    var overload:Int?
    
    let path:[String]
    
    init(label:Label, name:String, signature:[Signature.Token], declaration:[Declaration.Token], 
        fields:Fields, path:[String], inheritances:[[String]] = [])
    {
        self.overload       = nil 
        
        self.label          = label 
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        self.inheritances   = inheritances.filter{ !($0.first == "Swift") }
        
        self.blurb          = fields.blurb?.elements ?? [] 
        
        let relationships:[Markdown.Element] 
        switch label 
        {
        // "Required ..."
        case .initializer, .genericInitializer, .staticMethod, .genericStaticMethod, 
            .instanceMethod, .genericInstanceMethod, .staticProperty, .instanceProperty, 
            .subscript, .associatedtype, .typealias, .genericTypealias:
            guard fields.conformances.isEmpty 
            else 
            {
                fatalError("member '\(name)' cannot have conformances")
            }
            
            guard !fields.requirements.isEmpty 
            else 
            {
                fallthrough 
            }
            
            guard fields.implementations.isEmpty
            else 
            {
                fatalError("member '\(name)' cannot have both a requirement field and implementations fields.")
            }
            guard fields.extensions.isEmpty
            else 
            {
                fatalError("member '\(name)' cannot have both a requirement field and extension fields.")
            }
            
            if  case .required? = fields.requirements.first, 
                fields.requirements.count == 1 
            {
                relationships = .init(parsing: "**Required.**") 
                break 
            }
            if  case .defaulted(let conditions)? = fields.requirements.first, 
                fields.requirements.count == 1, 
                conditions.isEmpty 
            {
                relationships = .init(parsing: "**Required.** Default implementation provided.") 
                break 
            }
            
            let conditions:[[Grammar.WhereClause]] = fields.requirements.map 
            {
                guard case .defaulted(let conditions) = $0 
                else 
                {
                    fatalError("'required' for member '\(name)' is redundant if 'defaulted' fields are present")
                }
                
                guard !conditions.isEmpty 
                else 
                {
                    fatalError("conditional 'defaulted' for member '\(name)' cannot appear alongside unconditional 'defaulted'")
                }
                
                return conditions 
            }
            
            if conditions.count == 1 
            {
                relationships = .init(parsing: "**Required.** Default implementation provided when \(Self.prose(conditions: conditions[0])).")
            }
            else 
            {
                // render each condition on its own line 
                relationships = .init(parsing: "**Required.** \(conditions.map{ "\\nDefault implementation provided when \(Self.prose(conditions: $0))." }.joined())")
            }

        
        // "Implements requirement in ... . Available when ... ."
        //  or 
        // "Conforms to ... when ... ."
        case .enumeration, .genericEnumeration, .structure, .genericStructure, .class, .genericClass: 
            guard fields.requirements.isEmpty
            else 
            {
                fatalError("member '\(name)' cannot have a requirement field")
            }
            
            var sentences:[String] = []
            for `extension`:Grammar.ExtensionField in fields.extensions
            {
                sentences.append("Available when \(Self.prose(conditions: `extension`.conditions)).")
            }
            for implementation:Grammar.ImplementationField in fields.implementations
            {
                sentences.append("Implements requirement in [`\(implementation.conformance.joined(separator: "."))`].")
                if !implementation.conditions.isEmpty 
                {
                    sentences.append("Available when \(Self.prose(conditions: implementation.conditions)).")
                }
            }
            // non-conditional conformances go straight into the type declaration 
            for conformance:Grammar.ConformanceField in fields.conformances where !conformance.conditions.isEmpty 
            {
                let conformances:String = Self.prose(separator: ",", list: conformance.conformances.map 
                {
                    "[`\($0.joined(separator: "."))`]"
                })
                sentences.append("Conforms to \(conformances) when \(Self.prose(conditions: conformance.conditions)).")
            }
            
            relationships = .init(parsing: sentences.joined(separator: " "))
        
        case .protocol, .enumerationCase, .framework: 
            relationships = [] 
        }
        
        let specializations:[Markdown.Element] = .init(parsing: fields.attributes.compactMap 
        {
            guard case .specialized(let conditions) = $0 
            else 
            {
                return nil 
            }
            
            return "Specialization available when \(Self.prose(conditions: conditions.clauses))."
        }.joined(separator: "\\n"))
        
        self.discussion     = 
        (
            fields.parameters.map{ ($0.name, $0.paragraphs.map(\.elements)) }, 
            fields.return?.paragraphs.map(\.elements) ?? [], 
            fields.discussion.map(\.elements), 
            relationships,
            specializations
        )
        self.topics         = fields.topics
        
        var breadcrumbs:[(text:String, link:Link)] = [("Documentation", .unresolved(path: []))]
        +
        Link.link(path.map{ ($0, ()) }).map 
        {
            ($0.component.0, $0.link)
        }
        
        self.breadcrumb     = breadcrumbs.removeLast().text 
        self.breadcrumbs    = breadcrumbs
        
        self.path           = path
    }
    
    private static 
    func prose(conditions:[Grammar.WhereClause]) -> String 
    {
        return Self.prose(separator: ";", list: conditions.map 
        {
            (clause:Grammar.WhereClause) in 
            switch clause.predicate
            {
            case .equals(let type):
                return "[`\(clause.subject.joined(separator: "."))`] is [[`\(type)`]]"
            case .conforms(let protocols):
                let constraints:[String] = protocols.map{ "[`\($0.joined(separator: "."))`]" }
                return "[`\(clause.subject.joined(separator: "."))`] conforms to \(Self.prose(separator: ",", list: constraints))"
            }
        })
    }
    
    private static 
    func prose(separator:String, list:[String]) -> String 
    {
        guard let first:String = list.first 
        else 
        {
            fatalError("list must have at least one element")
        }
        guard let second:String = list.dropFirst().first 
        else 
        {
            return first 
        }
        guard let last:String = list.dropFirst(2).last 
        else 
        {
            return "\(first) and \(second)"
        }
        return "\(list.dropLast().joined(separator: "\(separator) "))\(separator) and \(last)"
    }
}
extension Page 
{
    private static 
    func crosslink(_ unlinked:[Markdown.Element], scopes:[PageTree.Node]) -> [Markdown.Element]
    {
        return unlinked.map
        {
            (element:Markdown.Element) in 
            
            switch element 
            {
            case .type(let inline):
                let tokens:[Declaration.Token] = Declaration.tokenize(inline.type).map 
                {
                    switch $0 
                    {
                    case .type(let component, .unresolved(path: let path)):
                        guard let url:String = PageTree.Node.resolve(path[...], in: scopes)
                        else 
                        {
                            return .identifier(component)
                        }
                        return .type(component, .resolved(url: url))
                    default:
                        return $0
                    }
                }
                return .code(tokens)
                
            case .symbol(let link):
                let tokens:[Declaration.Token] = link.paths.flatMap 
                {
                    (sublink:Markdown.Element.SymbolLink.Path) -> [Declaration.Token] in 
                    Link.link(sublink.path.map{ ($0, ()) }).map 
                    {
                        (element:(component:(String, Void), link:Link)) -> Declaration.Token in
                        
                        if case .unresolved(path: let path) = element.link 
                        {
                            let full:[String] = sublink.prefix + path 
                            guard let url:String = PageTree.Node.resolve(full[...], in: scopes)
                            else 
                            {
                                return .identifier(element.component.0)
                            }
                            
                            return .type(element.component.0, .resolved(url: url))
                        }
                        else 
                        {
                            return .type(element.component.0, element.link)
                        }
                        
                    }
                } 
                +
                link.suffix.map(Declaration.Token.identifier(_:))
                
                return .code(.init(tokens.map{ [$0] }.joined(separator: [.punctuation(".")])))
             
            default:
                return element
            }
        }
    }
    
    func crosslink(scopes:[PageTree.Node], node:PageTree.Node) 
    {
        self.declaration = self.declaration.map 
        {
            switch $0 
            {
            case .type(let component, .unresolved(path: let path)):
                guard let url:String = PageTree.Node.resolve(path[...], in: scopes)
                else 
                {
                    return .identifier(component)
                }
                return .type(component, .resolved(url: url))
            default:
                return $0
            }
        }
        
        // also search in the node’s own scope for the markdown links 
        let inclusive:[PageTree.Node] = scopes + [node]
        
        self.blurb                  = Self.crosslink(self.blurb, scopes: inclusive)
        self.discussion.parameters  = self.discussion.parameters.map 
        {
            ($0.name, $0.paragraphs.map{ Self.crosslink($0, scopes: inclusive) })
        }
        self.discussion.return      = self.discussion.return.map{   Self.crosslink($0, scopes: inclusive) }
        self.discussion.overview    = self.discussion.overview.map{ Self.crosslink($0, scopes: inclusive) }
        self.discussion.required        = 
            Self.crosslink(self.discussion.required, scopes: inclusive) 
        self.discussion.specializations = 
            Self.crosslink(self.discussion.specializations, scopes: inclusive) 
        
        self.breadcrumbs = self.breadcrumbs.map 
        {
            switch $0.link 
            {
            case .unresolved(path: let path):
                guard let url:String = PageTree.Node.resolve(path[...], in: inclusive)
                else 
                {
                    break 
                }
                return ($0.text, .resolved(url: url))
            default:
                break 
            }
            return $0
        }
    }
    
    enum ParameterScheme 
    {
        case `subscript`
        case function 
        case associatedValues 
        
        var delimiter:(String, String) 
        {
            switch self 
            {
            case .subscript:
                return ("[", "]")
            case .function, .associatedValues:
                return ("(", ")")
            }
        }
        
        func names(_ label:String, _ name:String) -> [String] 
        {
            switch self 
            {
            case .subscript:
                switch (label, name) 
                {
                case ("_",             "_"):
                    return ["_"]
                case ("_",       let inner):
                    return [inner]
                case (let outer, let inner):
                    return [outer, inner]
                }
            case .function:
                return label == name ? [label] : [label, name] 
            case .associatedValues:
                if label != name 
                {
                    Swift.print("warning: enumeration case cannot have different labels '\(label)', '\(name)'")
                }
                return label == "_" ? [] : [label]
            }
        }
    }
    
    static 
    func print(modifiers dispatch:Grammar.DispatchField, declaration:inout [Declaration.Token])
    {
        // iterate this way to always print the keywords in the correct order 
        for keyword:Grammar.DispatchField.Keyword in Grammar.DispatchField.Keyword.allCases 
        {
            if dispatch.keywords.contains(keyword)
            {
                declaration.append(.keyword("\(keyword)"))
                declaration.append(.breakableWhitespace)
            }
        }
    }
    
    static 
    func print(constraints:Grammar.ConstraintsField, declaration:inout [Declaration.Token], locals:Set<String>) 
    {
        declaration.append(.breakableWhitespace)
        declaration.append(.keyword("where"))
        declaration.append(.whitespace)
        declaration.append(contentsOf: constraints.clauses.map 
        {
            (clause:Grammar.WhereClause) -> [Page.Declaration.Token] in 
            var tokens:[Page.Declaration.Token] = []
            // strip links from lhs, as it’s too difficult to explore all the 
            // possible scopes their conformances provide
            tokens.append(contentsOf: Page.Declaration.tokenize(clause.subject).map 
            {
                if case .type(let string, _) = $0 
                {
                    return .identifier(string)
                }
                else 
                {
                    return $0
                }
            })
            switch clause.predicate 
            {
            case .conforms(let protocols):
                tokens.append(.punctuation(":"))
                // protocol types cannot possibly refer to local generics
                tokens.append(contentsOf: Page.Declaration.tokenize(.protocols(protocols)))
            case .equals(let type):
                tokens.append(.whitespace)
                tokens.append(.punctuation("=="))
                tokens.append(.whitespace)
                tokens.append(contentsOf: Page.Declaration.tokenize(type, locals: locals))
            }
            
            return tokens
        }.joined(separator: [.punctuation(","), .breakableWhitespace]))
    }
    static 
    func print(function fields:Fields, labels:[(name:String, variadic:Bool)], 
        scheme:ParameterScheme,
        signature:inout [Signature.Token], 
        declaration:inout [Declaration.Token], 
        locals:Set<String> = []) 
    {
        guard labels.count == fields.parameters.count 
        else 
        {
            fatalError("warning: function/subscript '\(signature)' has \(labels.count) labels, but \(fields.parameters.count) parameters")
        }
        
        signature.append(.punctuation(scheme.delimiter.0))
        declaration.append(.punctuation("("))
        
        var interior:(signature:[[Page.Signature.Token]], declaration:[[Page.Declaration.Token]]) = 
            ([], [])
        for ((label, variadic), (name, parameter, _)):
        (
            (String, Bool), 
            (String, Grammar.FunctionParameter, [Grammar.ParagraphField])
        ) in zip(labels, fields.parameters)
        {
            var signature:[Page.Signature.Token]        = []
            var declaration:[Page.Declaration.Token]    = []
            
            if label != "_" 
            {
                signature.append(.highlight(label))
                signature.append(.punctuation(":"))
            }
            
            let names:[String] = scheme.names(label, name)
            if !names.isEmpty 
            {
                declaration.append(contentsOf: names.map 
                {
                    [$0 == "_" ? .keyword($0) : .identifier($0)]
                }.joined(separator: [.whitespace]))
                declaration.append(.punctuation(":"))
            }
            for attribute:Grammar.Attribute in parameter.attributes
            {
                declaration.append(.keyword("\(attribute)"))
                declaration.append(.whitespace)
            }
            if parameter.inout 
            {
                signature.append(.text("inout"))
                signature.append(.whitespace)
                declaration.append(.keyword("inout"))
                declaration.append(.whitespace)
            }
            let type:(declaration:[Page.Declaration.Token], signature:[Page.Signature.Token]) 
            type.declaration = Page.Declaration.tokenize(parameter.type, locals: locals)
            type.signature   = Page.Signature.convert(type.declaration)
            signature.append(contentsOf: type.signature)
            declaration.append(contentsOf: type.declaration)
            
            if variadic 
            {
                signature.append(contentsOf: repeatElement(.punctuation("."), count: 3))
                declaration.append(contentsOf: repeatElement(.punctuation("."), count: 3))
            }
            
            interior.signature.append(signature)
            interior.declaration.append(declaration)
        }
        
        signature.append(contentsOf: 
            interior.signature.joined(separator: [.punctuation(","), .whitespace]))
        declaration.append(contentsOf: 
            interior.declaration.joined(separator: [.punctuation(","), .breakableWhitespace]))
        
        signature.append(.punctuation(scheme.delimiter.1))
        declaration.append(.punctuation(")"))
        
        if let `throws`:Grammar.ThrowsField = fields.throws
        {
            signature.append(.whitespace)
            signature.append(.text("\(`throws`)"))
            declaration.append(.breakableWhitespace)
            declaration.append(.keyword("\(`throws`)"))
        }
        
        if let type:Grammar.SwiftType = fields.return?.type 
        {
            signature.append(.whitespace)
            signature.append(.punctuation("->"))
            signature.append(.whitespace)
            declaration.append(.breakableWhitespace)
            declaration.append(.punctuation("->"))
            declaration.append(.whitespace)
            
            let tokens:[Page.Declaration.Token] = Page.Declaration.tokenize(type, locals: locals)
            signature.append(contentsOf: Page.Signature.convert(tokens))
            declaration.append(contentsOf: tokens)
        }
    }
}
extension Page 
{
    struct Fields
    {
        let conformances:[Grammar.ConformanceField], 
            implementations:[Grammar.ImplementationField], 
            extensions:[Grammar.ExtensionField], 
            constraints:Grammar.ConstraintsField?, 
            attributes:[Grammar.AttributeField], 
            paragraphs:[Grammar.ParagraphField],
            `throws`:Grammar.ThrowsField?, 
            dispatch:Grammar.DispatchField?, 
            requirements:[Grammar.RequirementField]
        let keys:Set<Page.Binding.Key>, 
            rank:Int, 
            order:Int, 
            topics:[Page.Topic]
        let parameters:[(name:String, type:Grammar.FunctionParameter, paragraphs:[Grammar.ParagraphField])], 
            `return`:(type:Grammar.SwiftType, paragraphs:[Grammar.ParagraphField])?
        
        var blurb:Grammar.ParagraphField?
        {
            self.paragraphs.first
        }
        var discussion:ArraySlice<Grammar.ParagraphField> 
        {
            self.paragraphs.dropFirst()
        }
        
        init<S>(_ fields:S, order:Int) where S:Sequence, S.Element == Grammar.Field 
        {
            var conformances:[Grammar.ConformanceField]         = [], 
                implementations:[Grammar.ImplementationField]   = [],
                extensions:[Grammar.ExtensionField]             = [], 
                requirements:[Grammar.RequirementField]         = [], 
                attributes:[Grammar.AttributeField]             = [], 
                paragraphs:[Grammar.ParagraphField]             = [],
                topics:[Grammar.TopicField]                     = [], 
                keys:[Grammar.TopicElementField]                = []
            var `throws`:Grammar.ThrowsField?, 
                dispatch:Grammar.DispatchField?,
                constraints:Grammar.ConstraintsField?
            var parameters:[(parameter:Grammar.ParameterField, paragraphs:[Grammar.ParagraphField])] = []
            
            for field:Grammar.Field in fields
            {
                switch field 
                {
                case .attribute     (let field):
                    attributes.append(field)
                case .conformance   (let field):
                    conformances.append(field)
                case .implementation(let field):
                    implementations.append(field)
                case .extension     (let field):
                    extensions.append(field)
                case .requirement   (let field):
                    requirements.append(field)
                
                case .constraints   (let field):
                    guard constraints == nil 
                    else 
                    {
                        fatalError("only one constraints field per doccomnent allowed")
                    }
                    constraints = field
                case .paragraph     (let field):
                    if parameters.isEmpty 
                    {
                        paragraphs.append(field)
                    }
                    else 
                    {
                        parameters[parameters.endIndex - 1].paragraphs.append(field)
                    }
                case .topic         (let field):
                    topics.append(field)
                case .topicElement  (let field):
                    keys.append(field)
                
                case .parameter     (let field):
                    parameters.append((field, []))
                    
                case .throws        (let field):
                    guard `throws` == nil 
                    else 
                    {
                        fatalError("only one throws field per doccomnent allowed")
                    }
                    `throws` = field 
                case .dispatch      (let field):
                    guard dispatch == nil 
                    else 
                    {
                        fatalError("only one dispatch field per doccomnent allowed")
                    }
                    dispatch = field 
                
                case .subscript, .function, .member, .type, .module:
                    fatalError("only one header field per doccomnent allowed")
                    
                case .separator:
                    break
                }
            }
            
            self.conformances       = conformances
            self.implementations    = implementations
            self.extensions         = extensions
            self.requirements       = requirements
            self.constraints        = constraints
            self.attributes         = attributes
            self.paragraphs         = paragraphs
            self.throws             = `throws`
            self.dispatch           = dispatch
            
            self.keys               = .init(keys.compactMap
            { 
                (element:Grammar.TopicElementField) in 
                element.key.map{ .init($0, rank: element.rank, order: order) } 
            })
            // collect anonymous topic element fields (of which there should be at most 1)
            let ranks:[Int]         = keys.compactMap 
            {
                (element:Grammar.TopicElementField) in 
                element.key == nil ? element.rank : nil 
            }
            guard ranks.count < 2 
            else 
            {
                fatalError("only one anonymous topic element field allowed per symbol")
            }
            self.rank               = ranks.first ?? .max
            // if there is no anonymous topic element field, we want to sort 
            // the symbols alphabetically, so we set the order to .max
            self.order              = ranks.isEmpty ? .max : order 
            
            self.topics             = topics.map{ ($0.display, $0.keys, []) }
            
            if  let (last, paragraphs):(Grammar.ParameterField, [Grammar.ParagraphField]) = 
                parameters.last, 
                case .return = last.name
            {
                self.return = (last.parameter.type, paragraphs)
                parameters.removeLast()
            }
            else 
            {
                self.return = nil
            }
            
            self.parameters = parameters.map 
            {
                guard case .parameter(let name) = $0.parameter.name 
                else 
                {
                    fatalError("return value must be the last parameter field")
                }
                return (name, $0.parameter.parameter, $0.paragraphs)
            }
        }
    }
}
extension Page.Binding 
{
    // permutes the overload index 
    func overload(_ overloads:Int) 
    {
        guard overloads > 0 
        else 
        {
            return 
        }
        
        print("note: overloaded symbol \(self.path.joined(separator: "."))")
        self.page.overload = overloads 
    }
    static 
    func create(_ header:Grammar.ModuleField, fields:ArraySlice<Grammar.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        
        let page:Page = .init(label: .framework, name: header.identifier, 
            signature:      [], 
            declaration:    [.keyword("import"), .whitespace, .identifier(header.identifier)], 
            fields:         fields, 
            path:           [])
        return .init(page, locals: [], keys: fields.keys, 
            rank: fields.rank, order: fields.order, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Grammar.SubscriptField, fields:ArraySlice<Grammar.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if fields.constraints != nil 
        {
            print("warning: where fields are ignored in a subscript doccomment")
        }
        
        let name:String = "[\(header.labels.map{ "\($0):" }.joined())]" 
        
        var declaration:[Page.Declaration.Token]    = 
            Page.Declaration.tokenize(fields.attributes) + [  .keyword("subscript")]
        var signature:[Page.Signature.Token]        =      [.highlight("subscript")]
        
        Page.print(function: fields, 
            labels: header.labels.map{ ($0, false) }, scheme: .subscript, 
            signature: &signature, declaration: &declaration)
        
        declaration.append(.breakableWhitespace)
        declaration.append(.punctuation("{"))
        declaration.append(.whitespace)
        declaration.append(.keyword("get"))
        switch header.mutability 
        {
        case .get:
            break 
        case .nonmutatingset:
            declaration.append(.whitespace)
            declaration.append(.keyword("nonmutating"))
            fallthrough
        case .getset:
            declaration.append(.whitespace)
            declaration.append(.keyword("set"))
        }
        declaration.append(.whitespace)
        declaration.append(.punctuation("}"))
        
        let page:Page = .init(label: .subscript, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers + [name])
        return .init(page, locals: [], keys: fields.keys, 
            rank: fields.rank, order: fields.order, urlpattern: urlpattern)
    }
    static 
    func create(_ header:Grammar.FunctionField, fields:ArraySlice<Grammar.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self 
    {
        let fields:Page.Fields = .init(fields, order: order)
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        switch (header.keyword, fields.dispatch)
        {
        case (.case, _?), (.staticFunc, _?):
            print("warning: dispatch field is ignored in a `case` or `static func` doccomment")
        case (_, let dispatch?):
            Page.print(modifiers: dispatch, declaration: &declaration)
        default:
            break 
        }
        
        let basename:String = header.identifiers[header.identifiers.endIndex - 1]

        let keywords:[String]
        switch header.keyword 
        {
        case .`init`:           keywords = []
        case .func:             keywords = ["func"]
        case .mutatingFunc:     keywords = ["mutating", "func"]
        case .staticFunc:       keywords = ["static", "func"]
        case .staticPrefixFunc: keywords = ["static", "prefix", "func"]
        case .staticPostfixFunc:keywords = ["static", "postfix", "func"]
        case .case:             keywords = ["case"]
        case .indirectCase:     keywords = ["indirect", "case"]
        }
        let label:Page.Label 
        switch (header.keyword, header.generics)
        {
        case (.`init`,          []):    label = .initializer 
        case (.`init`,          _ ):    label = .genericInitializer 
        
        case (.func,            []):    label = .instanceMethod 
        case (.func,            _ ):    label = .genericInstanceMethod 
        
        case (.mutatingFunc,    []):    label = .instanceMethod 
        case (.mutatingFunc,    _ ):    label = .genericInstanceMethod 
        
        case (.staticFunc,      []), (.staticPrefixFunc, []), (.staticPostfixFunc, []):    
                                        label = .staticMethod 
        case (.staticFunc,      _ ), (.staticPrefixFunc, _ ), (.staticPostfixFunc, _ ):    
                                        label = .genericStaticMethod 
        
        case (.case,            _ ):    label = .enumerationCase
        case (.indirectCase,    _ ):    label = .enumerationCase
        }
        
        var signature:[Page.Signature.Token] = keywords.flatMap 
        {
            [.text($0), .whitespace]
        }
        declaration.append(contentsOf: keywords.flatMap 
        {
            [.keyword($0), .breakableWhitespace]
        })
        
        signature.append(.highlight(basename))
        declaration.append(header.keyword == .`init` ? .keyword(basename) : .identifier(basename))
        
        if header.failable 
        {
            signature.append(.punctuation("?"))
            declaration.append(.typePunctuation("?", .appleify(["Swift", "Optional"])))
        }
        if !header.generics.isEmpty
        {
            var tokens:[Page.Declaration.Token] = []
            tokens.append(.punctuation("<"))
            tokens.append(contentsOf: header.generics.map
            { 
                [.identifier($0)] 
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
            tokens.append(.punctuation(">"))
            
            signature.append(contentsOf: Page.Signature.convert(tokens))
            declaration.append(contentsOf: tokens)
        }
        
        // does not include `Self`, since that refers to the parent node 
        let locals:Set<String> = .init(header.generics)
        
        let name:String 
        if case .enumerationCase = label, header.labels.isEmpty, fields.parameters.isEmpty 
        {
            name    = basename
        }
        else 
        {
            Page.print(function: fields, labels: header.labels, 
                scheme: header.keyword == .case ? .associatedValues : .function, 
                signature: &signature, declaration: &declaration, locals: locals)
            name    = "\(basename)(\(header.labels.map{ "\($0.variadic && $0.name == "_" ? "" : $0.name)\($0.variadic ? "..." : ""):" }.joined()))" 
        }
        
        if let constraints:Grammar.ConstraintsField = fields.constraints 
        {
            Page.print(constraints: constraints, declaration: &declaration, locals: locals) 
        }
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers.dropLast() + [name])
        // do not export locals, because this is a leaf node
        return .init(page, locals: [], keys: fields.keys, 
            rank: fields.rank, order: fields.order, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Grammar.MemberField, fields:ArraySlice<Grammar.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.parameters.isEmpty || fields.return != nil
        {
            print("warning: parameter/return fields are ignored in a member doccomment")
        }
        if fields.throws != nil
        {
            print("warning: throws fields are ignored in a member doccomment")
        }
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        switch (header.keyword, fields.dispatch)
        {
        case (.var, let dispatch?):
            Page.print(modifiers: dispatch, declaration: &declaration)
        case (_, _?):
            print("warning: dispatch field is ignored in member doccomment if keyword is not `var`") 
        default:
            break 
        }
        
        let name:String = header.identifiers[header.identifiers.endIndex - 1] 
        
        let keywords:[String],
            label:Page.Label 
        switch header.keyword
        {
        case .let:
            label       = .instanceProperty 
            keywords    = ["let"]
        case .var:
            label       = .instanceProperty 
            keywords    = ["var"]
        case .staticLet:
            label       = .staticProperty 
            keywords    = ["static", "let"]
        case .staticVar:
            label       = .staticProperty 
            keywords    = ["static", "var"]
        case .associatedtype:
            label       = .associatedtype 
            keywords    = ["associatedtype"]
        }
        
        let signature:[Page.Signature.Token]
        switch (header.type, header.mutability) 
        {
        case (nil, _?):
            fatalError("cannot have mutability annotation and no type annotation")
        case (nil, nil):
            guard label == .associatedtype 
            else 
            {
                fatalError("only associatedtype members can omit type annotation")
            }
            
            signature   = [.text("associatedtype"), .whitespace, .highlight(name)]
            declaration.append(.keyword("associatedtype"))
            declaration.append(.breakableWhitespace)
            declaration.append(.identifier(name))
        
        case (let type?, _):
            let type:[Page.Declaration.Token] = Page.Declaration.tokenize(type)
            signature = keywords.flatMap 
            {
                [.text($0), .whitespace]
            }
            + 
            [.highlight(name), .punctuation(":")]
            + 
            Page.Signature.convert(type)
            
            declaration.append(contentsOf: keywords.flatMap
            {
                [.keyword($0), .breakableWhitespace]
            })
            declaration.append(.identifier(name))
            declaration.append(.punctuation(":"))
            declaration.append(contentsOf: type)
            
            if let mutability:Grammar.MemberMutability = header.mutability 
            {
                declaration.append(.breakableWhitespace)
                declaration.append(.punctuation("{"))
                declaration.append(.whitespace)
                declaration.append(.keyword("get"))
                switch mutability 
                {
                case .get:
                    break 
                case .nonmutatingset:
                    declaration.append(.whitespace)
                    declaration.append(.keyword("nonmutating"))
                    fallthrough
                case .getset:
                    declaration.append(.whitespace)
                    declaration.append(.keyword("set"))
                }
                declaration.append(.whitespace)
                declaration.append(.punctuation("}"))
            }
        }
        
        if let constraints:Grammar.ConstraintsField = fields.constraints 
        {
            if case .associatedtype = header.keyword
            {
                Page.print(constraints: constraints, declaration: &declaration, locals: [name]) 
            }
            else 
            {
                print("warning: where fields are ignored in a non-`associatedtype` member doccomment")
            }
        }
        
        let page:Page       = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        return .init(page, locals: [], keys: fields.keys, 
            rank: fields.rank, order: fields.order, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Grammar.TypeField, fields:ArraySlice<Grammar.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.parameters.isEmpty || fields.return != nil
        {
            print("warning: parameter/return fields are ignored in a type doccomment")
        }
        if fields.throws != nil
        {
            print("warning: throws fields are ignored in a type doccomment")
        }
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        switch (header.keyword, fields.dispatch)
        {
        case (.class, let dispatch?):
            guard !dispatch.keywords.contains(.override)
            else 
            {
                fatalError("class \(header.identifiers) cannot have `override` modifier")
            }
            Page.print(modifiers: dispatch, declaration: &declaration)
        case (_, _?):
            print("warning: dispatch field is ignored in type doccomment if keyword is not `class`") 
        default:
            break 
        }
        
        let name:String = header.identifiers.joined(separator: ".")
        
        let label:Page.Label
        switch (header.keyword, header.generics) 
        {
        case (.protocol, []):
            label   = .protocol 
        case (.protocol, _):
            fatalError("protocol \(header.identifiers) cannot have generic parameters")
        
        case (.class, []):
            label   = .class 
        case (.class, _):
            label   = .genericClass 
        
        case (.struct, []):
            label   = .structure 
        case (.struct, _):
            label   = .genericStructure 
        
        case (.enum, []):
            label   = .enumeration
        case (.enum, _):
            label   = .genericEnumeration
        
        case (.typealias, []):
            label   = .typealias
        case (.typealias, _):
            label   = .genericTypealias
        }
        var signature:[Page.Signature.Token] = [.text("\(header.keyword)"), .whitespace] + 
            header.identifiers.map{ [.highlight($0)] }.joined(separator: [.punctuation(".")])
        
        declaration.append(.keyword("\(header.keyword)"))
        declaration.append(.breakableWhitespace)
        declaration.append(.identifier(header.identifiers[header.identifiers.endIndex - 1]))
        if !header.generics.isEmpty
        {
            signature.append(.punctuation("<"))
            declaration.append(.punctuation("<"))
            signature.append(contentsOf: header.generics.map
            { 
                [.text($0)] 
            }.joined(separator: [.punctuation(","), .whitespace]))
            declaration.append(contentsOf: header.generics.map
            { 
                [.identifier($0)] 
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
            signature.append(.punctuation(">"))
            declaration.append(.punctuation(">"))
        }
        
        let generics:Set<String>      = .init(header.generics), 
            locals:Set<String>        = generics.union(["Self"])
        
        // only put universal conformances in the declaration 
        let conformances:[[[String]]] = fields.conformances.compactMap 
        {
            $0.conditions.isEmpty ? $0.conformances : nil 
        }
        if !conformances.isEmpty 
        {
            declaration.append(.punctuation(":"))
            declaration.append(contentsOf: conformances.map 
            {
                $0.map(Page.Declaration.tokenize(_:))
                .joined(separator: [.punctuation("&")])
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
        }
        var inheritances:[[String]] = conformances.flatMap{ $0 }
        
        switch (header.keyword, header.target) 
        {
        case (.typealias, let target?):
            declaration.append(.whitespace)
            declaration.append(.punctuation("="))
            declaration.append(.breakableWhitespace)
            // do not include `Self` in locals
            declaration.append(contentsOf: Page.Declaration.tokenize(target, locals: generics))
            
            if case .named(let identifiers) = target 
            {
                inheritances.append(identifiers.map(\.identifier))
            }
            
        case (.typealias, nil):
            fatalError("typealias \(header.identifiers) requires a type target")
        case (_, _?):
            fatalError("type field \(header.identifiers) cannot have a type target")
        case (_, nil):
            break 
        }
        
        if let constraints:Grammar.ConstraintsField = fields.constraints
        {
            Page.print(constraints: constraints, declaration: &declaration, locals: locals) 
        }
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers, 
            inheritances:   inheritances)
        return .init(page, locals: locals, keys: fields.keys, 
            rank: fields.rank, order: fields.order, urlpattern: urlpattern)
    }
    
    func attachTopics<C>(children:C, global:[String: [Page.TopicSymbol]]) 
        where C:Collection, C.Element == PageTree.Node 
    {
        for i:Int in self.page.topics.indices 
        {
            self.page.topics[i].symbols.append(contentsOf: 
                self.page.topics[i].keys.flatMap
            {
                global[$0, default: []].filter 
                {
                    $0.url != self.url
                }
            })
        }
        let seen:Set<String> = .init(self.page.topics.flatMap{ $0.symbols.map(\.url) })
        var topics: 
        (
            enumerations        :[Page.TopicSymbol],
            structures          :[Page.TopicSymbol],
            classes             :[Page.TopicSymbol],
            protocols           :[Page.TopicSymbol],
            typealiases         :[Page.TopicSymbol],
            cases               :[Page.TopicSymbol],
            initializers        :[Page.TopicSymbol],
            typeMethods         :[Page.TopicSymbol],
            instanceMethods     :[Page.TopicSymbol],
            typeProperties      :[Page.TopicSymbol],
            instanceProperties  :[Page.TopicSymbol],
            associatedtypes     :[Page.TopicSymbol],
            subscripts          :[Page.TopicSymbol]
        )
        topics = ([], [], [], [], [], [], [], [], [], [], [], [], [])
        for binding:Self in 
            (children.flatMap
            { 
                $0.payloads.compactMap
                { 
                    if case .binding(let binding) = $0 
                    {
                        return binding 
                    }
                    else 
                    {
                        return nil 
                    }
                } 
            }.sorted
            { 
                ($0.rank, $0.order, $0.page.name) < ($1.rank, $1.order, $1.page.name) 
            })
        {
            guard !seen.contains(binding.url)
            else 
            {
                continue 
            }
            
            let symbol:Page.TopicSymbol = 
            (
                binding.page.signature, 
                binding.url, 
                binding.page.blurb, 
                binding.page.discussion.required
            )
            switch binding.page.label 
            {
            case .enumeration, .genericEnumeration:
                topics.enumerations.append(symbol)
            case .structure, .genericStructure:
                topics.structures.append(symbol)
            case .class, .genericClass:
                topics.classes.append(symbol)
            case .protocol:
                topics.protocols.append(symbol)
            case .typealias, .genericTypealias:
                topics.typealiases.append(symbol)
            
            case .enumerationCase:
                topics.cases.append(symbol)
            case .initializer, .genericInitializer:
                topics.initializers.append(symbol)
            case .staticMethod, .genericStaticMethod:
                topics.typeMethods.append(symbol)
            case .instanceMethod, .genericInstanceMethod:
                topics.instanceMethods.append(symbol)
            case .staticProperty:
                topics.typeProperties.append(symbol)
            case .instanceProperty:
                topics.instanceProperties.append(symbol)
            case .associatedtype:
                topics.associatedtypes.append(symbol)
            case .subscript:
                topics.subscripts.append(symbol)
            case .framework:
                break
            }
        }
        
        for builtin:(topic:String, symbols:[Page.TopicSymbol]) in 
        [
            (topic: "Enumeration cases",    symbols: topics.cases), 
            (topic: "Associated types",      symbols: topics.associatedtypes), 
            (topic: "Initializers",         symbols: topics.initializers), 
            (topic: "Subscripts",           symbols: topics.subscripts), 
            (topic: "Type properties",      symbols: topics.typeProperties), 
            (topic: "Instance properties",  symbols: topics.instanceProperties), 
            (topic: "Type methods",         symbols: topics.typeMethods), 
            (topic: "Instance methods",     symbols: topics.instanceMethods), 
            (topic: "Enumerations",         symbols: topics.enumerations), 
            (topic: "Structures",           symbols: topics.structures), 
            (topic: "Classes",              symbols: topics.classes), 
            (topic: "Protocols",            symbols: topics.protocols), 
            (topic: "Typealiases",          symbols: topics.typealiases), 
        ]
            where !builtin.symbols.isEmpty
        {
            self.page.topics.append((builtin.topic, ["$builtin"], builtin.symbols))
        }
        
        // move 'see also' to the end 
        if let i:Int = (self.page.topics.firstIndex{ $0.topic.lowercased() == "see also" })
        {
            let seealso:Page.Topic = self.page.topics.remove(at: i)
            self.page.topics.append(seealso)
        }
    }
}

struct PageTree 
{
    struct Node:CustomStringConvertible 
    {
        enum Payload:CustomStringConvertible
        {
            case binding(Page.Binding)
            case redirect(url:String)
            
            var url:String 
            {
                switch self 
                {
                case .binding(let binding):
                    return binding.url 
                case .redirect(url: let url):
                    return url 
                }
            }
            
            var description:String 
            {
                switch self 
                {
                case .binding(let binding):
                    return binding.path.joined(separator: ".") 
                case .redirect(url: let url):
                    return "<redirect: \(url)>"
                }
            }
        }
        
        var payloads:[Payload]
        var children:[String: Self]
        
        static 
        let empty:Self = .init(payloads: [], children: [:])
    }
}
extension PageTree.Node 
{
    mutating 
    func insert(_ binding:Page.Binding, at path:ArraySlice<String>) 
    {
        guard let key:String = path.first 
        else 
        {
            binding.overload(self.payloads.count)
            self.payloads.append(.binding(binding))
            return 
        }
        
        self.children[key, default: .empty].insert(binding, at: path.dropFirst())
    }
    mutating 
    func attachInheritedSymbols(scopes:[Self] = []) 
    {
        // go through the children first since we are writing to self.children later 
        let next:[Self] = scopes + [self]
        self.children = self.children.mapValues  
        {
            var child:Self = $0
            child.attachInheritedSymbols(scopes: next)
            return child
        }
        
        if case .binding(let binding)? = self.payloads.first 
        {
            // we also have to bring in everything the inheritances themselves inherit
            var inheritances:[[String]] = binding.page.inheritances
            while let path:[String] = inheritances.popLast() 
            {
                let (clones, next):([String: Self], [[String]]) = 
                    Self.clone(path[...], in: scopes)
                self.children.merge(clones) 
                { 
                    (current, _) in current 
                }
                
                inheritances.append(contentsOf: next)
            }
        }
    }
    
    var cloned:Self 
    {
        .init(payloads: self.payloads.map{ .redirect(url: $0.url) }, 
            children: self.children.mapValues(\.cloned))
    }
    static 
    func clone(_ path:ArraySlice<String>, in scopes:[Self]) -> (cloned:[String: Self], next:[[String]])
    {
        let debugPath:String = path.joined(separator: "/")
        higher:
        for scope:Self in scopes.reversed() 
        {
            var path:ArraySlice<String> = path, 
                scope:Self              = scope
            while let root:String = path.first 
            {
                if let next:Self = scope.children[root] 
                {
                    path    = path.dropFirst()
                    scope   = next 
                }
                else if case .binding(let binding)? = scope.payloads.first, 
                    binding.locals.contains(root), 
                    path.dropFirst().isEmpty
                {
                    break
                }
                else 
                {
                    continue higher 
                }
            }
            
            let inheritances:[[String]]
            if case .binding(let binding)? = scope.payloads.first 
            {
                inheritances = binding.page.inheritances
            }
            else 
            {
                inheritances = []
            }
            return (scope.children.mapValues(\.cloned), inheritances)
        }
        
        print("(PageTree.clone(_:in:)): failed to resolve '\(debugPath)'")
        return ([:], [])
    }
    static 
    func resolve(_ path:ArraySlice<String>, in scopes:[Self]) -> String?
    {
        if  path.isEmpty, 
            let root:Self       = scopes.first, 
            let payload:Payload = root.payloads.first
        {
            return payload.url 
        }
        
        let debugPath:String = path.joined(separator: "/")
        higher:
        for scope:Self in scopes.reversed() 
        {
            var path:ArraySlice<String> = path, 
                scope:Self              = scope
            while let root:String = path.first 
            {
                if      let next:Self = scope.children[root] 
                {
                    path    = path.dropFirst()
                    scope   = next 
                }
                else if case .binding(let binding)? = scope.payloads.first, 
                    binding.locals.contains(root), 
                    path.dropFirst().isEmpty
                {
                    break
                }
                else 
                {
                    continue higher 
                }
            }
            
            guard let payload:Payload = scope.payloads.first
            else 
            {
                break higher 
            }
            if scope.payloads.count > 1 
            {
                print("warning: path '\(debugPath)' is ambiguous")
            }
            
            return payload.url
        }
        
        print("(PageTree.resolve(_:in:)): failed to resolve '\(debugPath)'")
        print("note: searched in scopes \(scopes.map(\.payloads))")
        return nil
    }
    
    func traverse(scopes:[Self] = [], _ body:([Self], Self) throws -> ()) rethrows 
    {
        try body(scopes, self)
        
        let scopes:[Self] = scopes + [self]
        for child:Self in self.children.values 
        {
            try child.traverse(scopes: scopes, body)
        }
    }
    
    private  
    func describe(indent:Int = 0) -> String 
    {
        let strings:[String] = self.payloads.map 
        {
            "\(String.init(repeating: " ", count: indent * 4))\($0)\n"
        } 
        + 
        self.children.values.map 
        {
            $0.describe(indent: indent + 1)
        }
        return strings.joined()
    }
    
    var description:String 
    {
        self.describe()
    }
}        
extension PageTree 
{
    static 
    func assemble(_ pages:[Page.Binding]) -> Node 
    {
        var root:Node = .empty
        for page:Page.Binding in pages
        {
            root.insert(page, at: page.path[...])
        }
        
        // attach inherited symbols 
        root.attachInheritedSymbols()
        // resolve type links 
        root.traverse
        {
            (scopes:[Node], node:Node) in 
            for payload:Node.Payload in node.payloads
            {
                if case .binding(let binding) = payload 
                {
                    binding.page.crosslink(scopes: scopes, node: node)
                }
            }
        }
        
        // cannot collect anchors before resolving type links 
        var anchors:[String: [(rank:(Int, Int), symbol:Page.TopicSymbol)]] = [:]
        for (order, page):(Int, Page.Binding) in pages.enumerated()
        {
            let symbol:Page.TopicSymbol = 
            (
                page.page.signature, 
                page.url, 
                page.page.blurb,
                page.page.discussion.required
            )
            for key:Page.Binding.Key in page.keys 
            {
                anchors[key.key, default: []].append(((key.rank, order), symbol))
            }
        }
        // sort anchors 
        let global:[String: [Page.TopicSymbol]] = anchors.mapValues 
        {
            $0.sorted{ $0.rank < $1.rank }.map(\.symbol)
        }
        
        // attach topics 
        root.traverse
        {
            (_:[Node], node:Node) in 
            for payload:Node.Payload in node.payloads  
            {
                if case .binding(let binding) = payload 
                {
                    binding.attachTopics(children: node.children.values, global: global)
                }
            }
        }
        
        return root 
    }
}
