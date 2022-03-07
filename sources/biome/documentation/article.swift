import Markdown
import StructuredDocument 
import HTML

extension Biome 
{
    typealias Comment =
    (
        head:HTML.Element<Never>?, 
        parameters:[(name:String, comment:[HTML.Element<Never>])],
        returns:[HTML.Element<Never>],
        discussion:[HTML.Element<Never>]
    )
    
    struct Article 
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        
        /* enum Content
        {
            case documented(Element)
            case synthesized(from:Int)
            case inherited(from:Int)
        } */
        var navigator:Element
        {
            .text(escaped: self.baked.navigator)
        }
        var platforms:Element?
        {
            self.baked.platforms.map(Element.text(escaped:))
        }
        var summary:Element?
        {
            self.baked.summary.map(Element.text(escaped:))
        }
        /* var declaration:Element
        {
            .text(escaped: self.baked.declaration)
        } */
        var discussion:Element?
        {
            self.baked.discussion.map(Element.text(escaped:))
        }
        
        let errors:[Error]
        let introduction:Element 
        //let card:Element
        private 
        let baked:
        (
            navigator:String,
            summary:String?, 
            platforms:String?, 
        //    declaration:String,
            discussion:String?
        )
        
        var size:Int 
        {
            var size:Int = self.baked.navigator.utf8.count
            //size        += self.baked.declaration.utf8.count
            size        += self.baked.platforms?.utf8.count   ?? 0
            size        += self.baked.summary?.utf8.count     ?? 0
            size        += self.baked.discussion?.utf8.count  ?? 0
            return size
        }
        
        var substitutions:[Anchor: Element] 
        {
            var substitutions:[Anchor: Element] =
            [
                .navigator:     self.navigator,
                .introduction:  self.introduction,
            //    .declaration:   self.declaration,
            ]
            if let platforms:Element = self.platforms
            {
                substitutions[.platforms]   = platforms
            }
            if let summary:Element = self.summary
            {
                substitutions[.summary]     = summary
            }
            if let discussion:Element = self.discussion
            {
                substitutions[.discussion]  = discussion
            }
            return substitutions
        }
        
        init(//card:Element, 
            navigator:StaticElement, 
            introduction:Element, 
            summary:StaticElement?, 
            platforms:StaticElement?, 
            // declaration:StaticElement, 
            discussion:[StaticElement], 
            errors:[Error])
        {
            /* self.card               = .text(escaped: "")
            self.baked.navigator    = ""
            
            self.introduction       = .text(escaped: "")
            
            self.baked.summary      = ""
            self.baked.platforms    = ""
            self.baked.declaration  = ""
            self.baked.discussion   = "" */
            
            //self.card               = card
            self.baked.navigator    = navigator.rendered
            
            self.introduction       = introduction
            
            self.baked.summary      = summary?.rendered
            self.baked.platforms    = platforms?.rendered
            // self.baked.declaration  = declaration.rendered
            self.baked.discussion   = discussion.isEmpty ? nil : discussion.map(\.rendered).joined()
            
            self.errors             = errors 
        }
    }
    
    func article(package index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        // let card:Element        = Element[.li] 
        // { 
        //     self.packages[index].name 
        // }
        let navigator:StaticElement = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            StaticElement[.li] 
            { 
                self.packages[index].name 
            }
        }
        var renderer:ArticleRenderer    = .init(biome: self)
        let introduction:Element        = renderer.introduction(for: self.packages[index])
        // let declaration:StaticElement   = renderer.render(declaration: [])
        
        let comment:Comment             = renderer.content(markdown: comment)
        return .init(//card:  card, 
            navigator:      navigator, 
            introduction:   introduction,
            summary:        comment.head, 
            platforms:      nil,
            // declaration:    declaration,
            discussion:
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }, 
            errors:         renderer.errors)
    }
    func article(module index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        // let card:Element        = Element[.li] 
        // { 
        //     self.modules[index].title 
        // }
        let navigator:StaticElement = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            StaticElement[.li] 
            { 
                self.modules[index].title 
            }
        }
        var renderer:ArticleRenderer    = .init(biome: self)
        let introduction:Element        = renderer.introduction(for: self.modules[index])
        // let declaration:StaticElement   = renderer.render(declaration: self.modules[index].declaration)
        
        let comment:Comment             = renderer.content(markdown: comment)
        return .init(// card:  card, 
            navigator:      navigator, 
            introduction:   introduction,
            summary:        comment.head,
            platforms:      nil,
            // declaration:    declaration,
            discussion:     
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }, 
            errors:         renderer.errors)
    }
    func article(symbol index:Int, comment:String) -> Article
    {
        typealias Element           = HTML.Element<Anchor>
        typealias StaticElement     = HTML.Element<Never>
        let symbol:Symbol           = self.symbols[index]
        
        var breadcrumbs:[StaticElement]   = [ StaticElement[.li] { symbol.title } ]
        var next:Int?               = symbol.parent
        while let index:Int         = next
        {
            breadcrumbs.append(StaticElement[.li]
            {
                StaticElement.link(self.symbols[index].title, to: self.symbols[index].path.description, internal: true)
            })
            next = self.symbols[index].parent
        }
        breadcrumbs.reverse()
        
        let navigator:StaticElement  = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            breadcrumbs
        }
        
        var renderer:ArticleRenderer    = .init(biome: self)
        let introduction:Element        = renderer.introduction(for: symbol)
        // let declaration:StaticElement   = renderer.render(declaration: symbol.declaration)
        let summary:StaticElement?, 
            discussion:[StaticElement]
        if case _? = symbol.commentOrigin 
        {
            // don’t re-render duplicated docs 
            summary             = nil 
            discussion          = []
        }
        else 
        {
            let comment:Comment = renderer.content(markdown: comment)
            summary             = comment.head
            discussion          = 
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }
        }
        return .init(// card:  self.card(symbol: index), 
            navigator:      navigator, 
            introduction:   introduction,
            summary:        summary, 
            platforms:      ArticleRenderer.render(platforms: symbol.platforms),
            // declaration:    declaration,
            discussion:     discussion, 
            errors:         renderer.errors)
    }
}
extension Biome 
{
    struct ArticleRenderer 
    {
        typealias Element = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        
        let biome:Biome 
        var errors:[Error]
        
        init(biome:Biome)
        {
            self.biome = biome 
            self.errors = []
        }
        
        mutating 
        func render<ID>(code:[SwiftLanguage.Lexeme<Symbol.ID>], anchors _:ID.Type = ID.self) -> [HTML.Element<ID>] 
        {
            code.map 
            {
                self.render(lexeme: $0, anchors: ID.self)
            }
        }
        mutating 
        func render<ID>(lexeme:SwiftLanguage.Lexeme<Symbol.ID>, anchors _:ID.Type = ID.self) -> HTML.Element<ID>
        {
            guard case .code(let text, class: .type(let id?)) = lexeme
            else 
            {
                return Biome.render(lexeme: lexeme)
            }
            guard let path:Path = self.biome.symbols[id]?.path
            else 
            {
                self.errors.append(SymbolIdentifierError.undefined(symbol: id))
                return Biome.render(lexeme: lexeme)
            }
            return HTML.Element<ID>.link(text, to: path.description, internal: true)
            {
                ["syntax-type"] 
            }
        }
        mutating 
        func render(constraint:SwiftLanguage.Constraint<Symbol.ID>) -> [Element] 
        {
            let subject:SwiftLanguage.Lexeme<Symbol.ID> = .code(constraint.subject, class: .type(nil))
            let prose:String
            let object:Symbol.ID?
            switch constraint.verb
            {
            case .inherits(from: let id): 
                prose   = " inherits from "
                object  = id
            case .conforms(to: let id):
                prose   = " conforms to "
                object  = id
            case .is(let id):
                prose   = " is "
                object  = id
            }
            return 
                [
                    Element[.code]
                    {
                        self.render(lexeme: subject)
                    },
                    Element.text(escaped: prose), 
                    Element[.code]
                    {
                        self.render(lexeme: .code(constraint.object, class: .type(object)))
                    },
                ]
        }
        mutating 
        func render(constraints:[SwiftLanguage.Constraint<Symbol.ID>]) -> [Element] 
        {
            guard let ultimate:SwiftLanguage.Constraint<Symbol.ID> = constraints.last 
            else 
            {
                fatalError("cannot call \(#function) with empty constraints array")
            }
            guard let penultimate:SwiftLanguage.Constraint<Symbol.ID> = constraints.dropLast().last
            else 
            {
                return self.render(constraint: ultimate)
            }
            var fragments:[Element]
            if constraints.count < 3 
            {
                fragments =                  self.render(constraint: penultimate)
                fragments.append(.text(escaped: " and "))
                fragments.append(contentsOf: self.render(constraint: ultimate))
            }
            else 
            {
                fragments = []
                for constraint:SwiftLanguage.Constraint<Symbol.ID> in constraints.dropLast(2)
                {
                    fragments.append(contentsOf: self.render(constraint: constraint))
                    fragments.append(.text(escaped: ", "))
                }
                fragments.append(contentsOf: self.render(constraint: penultimate))
                fragments.append(.text(escaped: ", and "))
                fragments.append(contentsOf: self.render(constraint: ultimate))
            }
            return fragments
        }
        /* mutating 
        func render(declaration:[SwiftLanguage.Lexeme<Symbol.ID>]) -> StaticElement
        {
            StaticElement[.section]
            {
                ["declaration"]
            }
            content:
            {
                StaticElement[.h2]
                {
                    "Declaration"
                }
                StaticElement[.pre]
                {
                    StaticElement[.code] 
                    {
                        ["swift"]
                    }
                    content: 
                    {
                        self.render(code: declaration)
                    }
                }
            }
        } */
        
        static
        func render(platforms availability:[Symbol.Domain: Symbol.Availability]) -> StaticElement?
        {
            var platforms:[StaticElement] = []
            for platform:Symbol.Domain in Symbol.Domain.platforms 
            {
                if let availability:Symbol.Availability = availability[platform]
                {
                    if availability.unavailable 
                    {
                        platforms.append(StaticElement[.li]
                        {
                            "\(platform.rawValue) unavailable"
                        })
                    }
                    else if case nil? = availability.deprecated 
                    {
                        platforms.append(StaticElement[.li]
                        {
                            "\(platform.rawValue) deprecated"
                        })
                    }
                    else if case let version?? = availability.deprecated 
                    {
                        platforms.append(StaticElement[.li]
                        {
                            "\(platform.rawValue) deprecated since "
                            StaticElement.span("\(version.description)")
                            {
                                ["version"]
                            }
                        })
                    }
                    else if let version:Version = availability.introduced 
                    {
                        platforms.append(StaticElement[.li]
                        {
                            "\(platform.rawValue) "
                            StaticElement.span("\(version.description)+")
                            {
                                ["version"]
                            }
                        })
                    }
                }
            }
            guard !platforms.isEmpty
            else 
            {
                return nil
            }
            return StaticElement[.section]
            {
                ["platforms"]
            }
            content: 
            {
                StaticElement[.ul]
                {
                    platforms
                }
            }
        }
        
        // could be static 
        func introduction(for package:Package) -> Element
        {
            Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                self.eyebrows(for: package)
                Element[.h1]
                {
                    package.name
                }
                Element.anchor(id: .summary)
            }
        }
        // could be static 
        func introduction(for module:Module) -> Element
        {
            Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                self.eyebrows(for: module)
                Element[.h1]
                {
                    module.title
                }
                Element.anchor(id: .summary)
            }
        }
        mutating 
        func introduction(for symbol:Symbol) -> Element
        {
            var relationships:[Element] 
            if case _? = symbol.relationships.requirementOf
            {
                relationships = 
                [
                    Element[.li] 
                    {
                        Element[.p]
                        {
                            ["required"]
                        }
                        content:
                        {
                            "Required."
                        }
                    }
                ]
            }
            else 
            {
                relationships = []
            }
            // TODO: need to rework this, because real types can still inherit 
            // docs, if they satisfy protocol requirements and have no documentation 
            // of their own...
            
            /* if  let origin:Int = symbol.relationships.sourceOrigin 
                let conformance:Int = self.biome.symbols[origin].lineage.parent 
            {
                relationships.append(Element[.li] 
                {
                    Element[.p]
                    {
                        Element.link("Inherited", to: self.biome.symbols[origin].path.description, internal: true)
                        " from "
                        Element[.code]
                        {
                            Element[.a]
                            {
                                (self.biome.symbols[conformance].path.description, as: HTML.Href.self)
                            }
                            content: 
                            {
                                Biome.render(code: self.biome.symbols[conformance].qualified)
                            }
                        }
                    }
                })
            } */
            if !symbol.extensionConstraints.isEmpty
            {
                relationships.append(Element[.li] 
                {
                    Element[.p]
                    {
                        "Available when "
                        self.render(constraints: symbol.extensionConstraints)
                    }
                })
            }
            let availability:[Element] = Biome.render(availability: symbol.availability)
            return Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                self.eyebrows(for: symbol)
                Element[.h1]
                {
                    symbol.title
                }
                Element.anchor(id: .summary)
                if !relationships.isEmpty 
                {
                    Element[.ul]
                    {
                        ["relationships-list"]
                    }
                    content: 
                    {
                        relationships
                    }
                }
                if !availability.isEmpty 
                {
                    Element[.ul]
                    {
                        ["availability-list"]
                    }
                    content: 
                    {
                        availability
                    }
                }
            }
        }
        
        private 
        func eyebrows(for package:Package) -> Element
        {
            Element[.div]
            {
                ["eyebrows"]
            }
            content:
            {
                if case .swift = package.id 
                {
                    Element.span("Standard Library")
                    {
                        ["kind"]
                    }
                }
                else 
                {
                    Element.span("Package")
                    {
                        ["kind"]
                    }
                }
            }
        }
        private 
        func eyebrows(for module:Module) -> Element
        {
            Element[.div]
            {
                ["eyebrows"]
            }
            content:
            {
                Element.span("Module")
                {
                    ["kind"]
                }
                Element[.span]
                {
                    ["package"]
                }
                content:
                {
                    Element.link(self.biome.packages[module.package].name, 
                        to: self.biome.packages[module.package].path.description, 
                        internal: true)
                }
            }
        }
        private 
        func eyebrows(for symbol:Symbol) -> Element
        {
            Element[.div]
            {
                ["eyebrows"]
            }
            content:
            {
                Element.span(symbol.kind.title)
                {
                    ["kind"]
                }
                Element[.span]
                {
                    ["module"]
                }
                content: 
                {
                    if let extended:Int = symbol.bystander
                    {
                        Element[.span]
                        {
                            ["extended"]
                        }
                        content:
                        {
                            Element.link(self.biome.modules[extended].title, to: self.biome.modules[extended].path.description, internal: true)
                        }
                    }
                    Element.link(self.biome.modules[symbol.module].title, to: self.biome.modules[symbol.module].path.description, internal: true)
                }
            }
        }
        
        static 
        func render(section content:[StaticElement], heading:String, class:String) -> StaticElement?
        {
            guard !content.isEmpty 
            else 
            {
                return nil 
            }
            return StaticElement[.section]
            {
                [`class`]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    heading
                }
                content
            }
        }
        static 
        func render(parameters:[(name:String, comment:[StaticElement])]) -> StaticElement?
        {
            guard !parameters.isEmpty 
            else 
            {
                return nil 
            }
            return StaticElement[.section]
            {
                ["parameters"]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    "Parameters"
                }
                StaticElement[.dl]
                {
                    for (name, comment):(String, [StaticElement]) in parameters 
                    {
                        StaticElement[.dt]
                        {
                            name
                        }
                        StaticElement[.dd]
                        {
                            comment
                        }
                    }
                }
            }
        }
        
        mutating 
        func content(markdown string:String) -> Comment
        {
            guard !string.isEmpty 
            else 
            {
                return (nil, [], [], [])
            }
            return self.content(markdown: Markdown.Document.init(parsing: string))
        }
        // expected parameters is unreliable, not available for subscripts
        private mutating 
        func content(markdown document:Markdown.Document) -> Comment
        {
            let content:[StaticElement] = document.blockChildren.map { self.render(markup: $0) }
            let head:StaticElement?
            let body:ArraySlice<StaticElement>
            if  let first:StaticElement = content.first, 
                case .container(.p, id: _, attributes: _, content: _) = first
            {
                head = first
                body = content.dropFirst()
            }
            else 
            {
                head = nil 
                body = content[...]
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            var returns:[StaticElement]      = []
            var discussion:[StaticElement]   = []
            for block:StaticElement in body 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[StaticElement] = []
                for item:StaticElement in items
                {
                    guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                            let (keywords, content):([String], [StaticElement]) = Biome.keywords(prefixing: content)
                    else 
                    {
                        ignored.append(item)
                        continue 
                    }
                    // `keywords` always contains at least one keyword
                    let keyword:String = keywords[0]
                    do 
                    {
                        switch keyword
                        {
                        case "parameters": 
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            parameters.append(contentsOf: try Self.parameters(in: content))
                            
                        case "parameter": 
                            guard keywords.count == 2 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            let name:String = keywords[1]
                            if content.isEmpty
                            {
                                throw ArticleParametersError.empty(parameter: name)
                            } 
                            parameters.append((name, content))
                        
                        case "returns":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            if content.isEmpty
                            {
                                throw ArticleReturnsError.empty
                            }
                            if returns.isEmpty 
                            {
                                returns = content
                            }
                            else 
                            {
                                throw ArticleReturnsError.duplicate(section: returns)
                            }
                        
                        case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            discussion.append(StaticElement[.aside]
                            {
                                [keyword]
                            }
                            content:
                            {
                                StaticElement[.h2]
                                {
                                    keyword
                                }
                                
                                content
                            })
                            
                        default:
                            throw ArticleAsideError.undefined(keywords: keywords)
                            /* if case _? = comment.complexity 
                            {
                                print("warning: detected multiple 'complexity' sections, only the last will be used")
                            }
                            guard   let first:Markdown.BlockMarkup = content.first, 
                                    let first:Markdown.Paragraph = first as? Markdown.Paragraph
                            else 
                            {
                                print("warning: could not detect complexity function from section \(content)")
                                ignored.append(item)
                                continue 
                            }
                            let text:String = first.inlineChildren.map(\.plainText).joined()
                            switch text.firstIndex(of: ")").map(text.prefix(through:))
                            {
                            case "O(1)"?: 
                                comment.complexity = .constant
                            case "O(n)"?, "O(m)"?: 
                                comment.complexity = .linear
                            case "O(n log n)"?: 
                                comment.complexity = .logLinear
                            default:
                                print("warning: could not detect complexity function from string '\(text)'")
                                ignored.append(item)
                                continue 
                            } */
                        }
                    }
                    catch let error 
                    {
                        self.errors.append(error)
                        ignored.append(item)
                    }
                }
                guard ignored.isEmpty 
                else 
                {
                    discussion.append(.container(.ul, id: id, attributes: attributes, content: ignored))
                    continue 
                }
            }
            
            return (head, parameters, returns, discussion)
        }
        private static
        func parameters(in content:[StaticElement]) throws -> [(name:String, comment:[StaticElement])]
        {
            guard let first:StaticElement = content.first 
            else 
            {
                throw ArticleParametersError.empty(parameter: nil)
            }
            // look for a nested list 
            guard case .container(.ul, id: _, attributes: _, content: let items) = first 
            else 
            {
                throw ArticleParametersError.invalidList(first)
            }
            if case _? = content.dropFirst().first
            {
                throw ArticleParametersError.multipleLists(content)
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            for item:StaticElement in items
            {
                guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [StaticElement]) = Biome.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw ArticleParametersError.invalidListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        private mutating  
        func render(markup:Markdown.Markup) -> StaticElement
        {
            let container:HTML.Container 
            switch markup 
            {
            case is Markdown.LineBreak:             return StaticElement[.br]
            case is Markdown.SoftBreak:             return StaticElement.text(escaped: " ")
            case is Markdown.ThematicBreak:         return StaticElement[.hr]
            case let node as Markdown.CustomInline: return StaticElement.text(escaping: node.text)
            case let node as Markdown.Text:         return StaticElement.text(escaping: node.string)
            case let node as Markdown.HTMLBlock:    return StaticElement.text(escaped: node.rawHTML)
            case let node as Markdown.InlineHTML:   return StaticElement.text(escaped: node.rawHTML)
            
            case is Markdown.Document:          container = .main
            case is Markdown.BlockQuote:        container = .blockquote
            case is Markdown.Emphasis:          container = .em
            case let node as Markdown.Heading: 
                switch node.level 
                {
                case 1:                         container = .h2
                case 2:                         container = .h3
                case 3:                         container = .h4
                case 4:                         container = .h5
                default:                        container = .h6
                }
            case is Markdown.ListItem:          container = .li
            case is Markdown.OrderedList:       container = .ol
            case is Markdown.Paragraph:         container = .p
            case is Markdown.Strikethrough:     container = .s
            case is Markdown.Strong:            container = .strong
            case is Markdown.Table:             container = .table
            case is Markdown.Table.Row:         container = .tr
            case is Markdown.Table.Head:        container = .thead
            case is Markdown.Table.Body:        container = .tbody
            case is Markdown.Table.Cell:        container = .td
            case is Markdown.UnorderedList:     container = .ul
            
            case let node as Markdown.CodeBlock: 
                return StaticElement[.pre]
                {
                    ["notebook"]
                }
                content:
                {
                    StaticElement[.code]
                    {
                        Biome.render(lexeme: .newlines(0))
                        Biome.render(code: SwiftLanguage.highlight(code: node.code, links: Symbol.ID.self))
                    }
                }
            case let node as Markdown.InlineCode: 
                return StaticElement[.code]
                {
                    node.code
                }

            case is Markdown.BlockDirective: 
                return StaticElement[.div]
                {
                    "(unsupported block directive)"
                }
            
            case let node as Markdown.Image: 
                // TODO: do something with these
                let _:String?       = node.title 
                let _:[StaticElement]    = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let source:String = node.source
                else 
                {
                    self.errors.append(ArticleContentError.missingImageSource)
                    return StaticElement[.img]
                }
                return StaticElement[.img]
                {
                    (source, as: HTML.Src.self)
                }
            
            case let node as Markdown.Link: 
                let display:[StaticElement] = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let target:String = node.destination
                else 
                {
                    self.errors.append(ArticleContentError.missingLinkDestination)
                    return StaticElement[.span]
                    {
                        display
                    }
                }
                return StaticElement[.a]
                {
                    (target, as: HTML.Href.self)
                    HTML.Target._blank
                    HTML.Rel.nofollow
                }
                content:
                {
                    display
                }
                
            case let node as Markdown.SymbolLink: 
                guard let path:String = node.destination
                else 
                {
                    self.errors.append(ArticleSymbolLinkError.empty)
                    return StaticElement[.code]
                    {
                        "<empty symbol path>"
                    }
                }
                return StaticElement[.code]
                {
                    path
                }
                
            case let node: 
                self.errors.append(ArticleContentError.unsupported(markup: node))
                return StaticElement[.div]
                {
                    "(unsupported markdown node '\(type(of: node))')"
                }
            }
            return StaticElement[container]
            {
                markup.children.map
                {
                    self.render(markup: $0)
                }
            }
        }
    }
}
