import StructuredDocument 
import HTML 

extension Biome 
{
    public 
    typealias Frontend  = Document.Element<HTML, Anchor>
    
    func render(constraint:Language.Constraint) -> [Frontend] 
    {
        let subject:Language.Lexeme = .code(constraint.subject, class: .type(nil))
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
                Frontend[.code]
                {
                    Self.render(lexeme: subject) { self[id: $0] }
                },
                Frontend.text(escaped: prose), 
                Frontend[.code]
                {
                    Self.render(lexeme: .code(constraint.object, class: .type(object))) { self[id: $0] }
                },
            ]
    }
    func render(constraints:[Language.Constraint]) -> [Frontend] 
    {
        guard let ultimate:Language.Constraint = constraints.last 
        else 
        {
            fatalError("cannot call \(#function) with empty constraints array")
        }
        guard let penultimate:Language.Constraint = constraints.dropLast().last
        else 
        {
            return self.render(constraint: ultimate)
        }
        if constraints.count < 3 
        {
            return self.render(constraint: penultimate) + 
                CollectionOfOne<Frontend>.init(.text(escaped: " and ")) + 
                self.render(constraint: ultimate)
        }
        else 
        {
            var fragments:[Frontend] = .init(constraints.dropLast()
                .map(self.render(constraint:))
                .joined(separator: CollectionOfOne<Frontend>.init(.text(escaped: ", "))))
            fragments.append(.text(escaped: ", and "))
            fragments.append(contentsOf: self.render(constraint: ultimate))
            return fragments
        }
    }
    static 
    func render(lexeme:Language.Lexeme, resolve:((Symbol.ID) -> Symbol?)? = nil) -> Frontend
    {
        switch lexeme
        {
        case .code(let text, class: let classification):
            let css:String
            switch classification 
            {
            case .punctuation: 
                return Frontend.text(escaping: text)
            case .type(let id?):
                guard let resolve:(Symbol.ID) -> Symbol? = resolve 
                else 
                {
                    fallthrough
                }
                guard let resolved:Symbol = resolve(id)
                else 
                {
                    print("warning: no symbol for id '\(id)'")
                    fallthrough
                }
                return Frontend.link(text, to: resolved.path.canonical, internal: true)
                {
                    ["syntax-type"] 
                }
            case .type(nil):
                css = "syntax-type"
            case .identifier:
                css = "syntax-identifier"
            case .generic:
                css = "syntax-generic"
            case .argument:
                css = "syntax-parameter-label"
            case .parameter:
                css = "syntax-parameter-name"
            case .directive, .attribute, .keyword(.other):
                css = "syntax-keyword"
            case .keyword(.`init`):
                css = "syntax-keyword syntax-swift-init"
            case .keyword(.deinit):
                css = "syntax-keyword syntax-swift-deinit"
            case .keyword(.subscript):
                css = "syntax-keyword syntax-swift-subscript"
            case .pseudo:
                css = "syntax-pseudo-identifier"
            case .number, .string:
                css = "syntax-literal"
            case .interpolation:
                css = "syntax-interpolation-anchor"
            case .macro:
                css = "syntax-macro"
            }
            return Frontend.span(text)
            {
                [css]
            }
        case .comment(let text, documentation: _):
            return Frontend.span(text)
            {
                ["syntax-comment"]
            } 
        case .invalid(let text):
            return Frontend.span(text)
            {
                ["syntax-invalid"]
            } 
        case .newlines(let count):
            return Frontend.span(String.init(repeating: "\n", count: count))
            {
                ["syntax-newline"]
            } 
        case .spaces(let count):
            return Frontend.text(escaped: String.init(repeating: " ", count: count)) 
        }
    }
    static 
    func render(code:[Language.Lexeme], resolve:((Symbol.ID) -> Symbol?)? = nil) -> [Frontend] 
    {
        code.map { Self.render(lexeme: $0, resolve: resolve) }
    }
    func render(code:[Language.Lexeme]) -> [Frontend] 
    {
        Self.render(code: code) { self[id: $0] }
    }
}
extension Biome 
{
    func renderSymbolLink(to path:String?) -> Frontend
    {
        Frontend[.code]
        {
            path ?? "<unknown>"
        }
    }
    func renderLink(to target:String?, _ content:[Frontend]) -> Frontend
    {
        if let target:String = target
        {
            return Frontend[.a]
            {
                (target, as: HTML.Href.self)
                HTML.Target._blank
                HTML.Rel.nofollow
            }
            content:
            {
                content
            }
        }
        else 
        {
            return Frontend[.span]
            {
                content
            }
        }
    }
    func renderImage(source:String?, alt:[Frontend], title:String?) -> Frontend
    {
        if let source:String = source
        {
            return Frontend[.img]
            {
                (source, as: HTML.Src.self)
            }
        }
        else 
        {
            return Frontend[.img]
        }
    }
    func renderNotebook(highlighting code:String) -> Frontend
    {
        Frontend[.pre]
        {
            ["notebook"]
        }
        content:
        {
            Frontend[.code]
            {
                Self.render(lexeme: .newlines(0))
                self.render(code: Language.highlight(code: code))
            }
        }
    }
}
