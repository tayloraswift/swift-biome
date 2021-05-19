enum Options 
{
    case directory 
    case urlprefix
    case urlsuffix 
    case github
    case project
    case theme
    case verbose
}

func pages(sources:[String], directory:String, urlpattern:(prefix:String, suffix:String), github:String, project:String, theme:String, verbose:Bool)
{
    var doccomments:[String] = [] 
    for path:String in sources 
    {
        guard let contents:String = File.source(path: path) 
        else 
        {
            continue 
        }
        
        var doccomment:String = ""
        for line:Substring in contents.split(separator: "\n", omittingEmptySubsequences: false)
        {
            let line:Substring = line.drop{ $0.isWhitespace && !$0.isNewline }
            if line.starts(with: "/// ")
            {
                doccomment += "\(line.dropFirst(4))\n"
            } 
            else if line.starts(with: "///"), 
                    line.dropFirst(3).allSatisfy(\.isWhitespace)
            {
                doccomment += "\n"
            }
            else if !doccomment.isEmpty
            {
                doccomments.append(doccomment)
                doccomment = ""
            }
        }
        
        if !doccomment.isEmpty
        {
            doccomments.append(doccomment)
        }
    }
    
    // tree building 
    let root:Node = .init(parent: nil)
    withExtendedLifetime(root)
    {
        for (i, doccomment):(Int, String) in doccomments.enumerated()
        {
            do 
            {
                let parsed:[Grammar.Field]  =     .init(parsing: doccomment), 
                    fields:Node.Page.Fields = try .init(parsed.dropFirst())
                
                switch parsed.first 
                {
                case .framework (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .dependency(let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .subscript (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .function  (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .property  (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .typealias (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                case .type      (let header)?:
                    root.insert(try .init(header, fields: fields, order: i))
                default:
                    throw Entrapta.Error.init("could not parse doccomment")
                }
            }
            catch let error as Entrapta.Error 
            {
                print("error: \(error.message)")
                print(
                    """
                    note: while parsing doccomment 
                    '''
                    \(doccomment)
                    '''
                    """)
                continue 
            }
            catch 
            {
                continue 
            }
        }
        
        // print out root 
        if verbose 
        {
            print(root)
        }
        
        root.assignAnchors(urlpattern: urlpattern)
        root.attachTopics()
        root.resolveLinks()
        
        guard   let fonts:String = File.source(path: "themes/\(theme)/fonts"),
                let css:String   = File.source(path: "themes/\(theme)/style.css") 
        else 
        {
            fatalError("failed to load theme '\(theme)'") 
        }
        
        for page:Node.Page in root.preorder.flatMap(\.pages)
        {
            guard let anchor:(url:String, directory:[String]) = page.anchor 
            else 
            {
                fatalError("unreachable")
            }
            
            let document:String = 
            """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
            \(fonts)
                <link href="\(urlpattern.prefix)/style.css" rel="stylesheet"> 
                <title>\(page.name) - \(project)</title>
            </head> 
            <body>
                \(page.html(github: github).rendered)
            </body>
            </html>
            """
            File.pave([directory] + anchor.directory)
            File.save(.init(document.utf8), path: "\(directory)/\(anchor.directory.joined(separator: "/"))/index.html")
        }
        
        // create 404 page 
        let notfound:String = 
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
        \(fonts)
            <link href="\(urlpattern.prefix)/style.css" rel="stylesheet"> 
            <title>Page not found - \(project)</title>
        </head> 
        <body>
            <main>
                <nav>
                    <div class="navigation-container">
                        <ul><li class="github-icon-container"><a href="\(github)"><span class="github-icon" title="Github repository"></span></a></li></ul>
                    </div>
                </nav>
                <section class="introduction">
                    <div class="section-container error-404-message">
                        <h1 class="topic-heading">query not recognized</h1>
                        <p>What is your query?</p>
                        <p><a href="\(urlpattern.prefix)/\(urlpattern.suffix)">Go to documentation root</a></p>
                    </div>
                </section>
            </main>
        </body>
        </html>
        """
        File.save(.init(notfound.utf8), path: "\(directory)/404.html")
        
        // emit stylesheet 
        File.save(.init(css.utf8), path: "\(directory)/style.css")
        // copy github-icon.svg 
        guard let icon:String = File.source(path: "sources/github-icon.svg") 
        else 
        {
            fatalError("missing github icon") 
        }
        File.save(.init(icon.utf8), path: "\(directory)/github-icon.svg") 
    }
}

var sources:[String]                    = []
var directory:String                    = "documentation"
var url:(prefix:String, suffix:String)  = ("", "")
var github:String                       = "https://github.com"
var project:String?
var theme:String                        = "big-sur"
var verbose:Bool                        = false

func help() 
{
    print("""
    usage: \(CommandLine.arguments[0]) sources... [-d/--directory directory] [-p/--url-prefix prefix] [-s/--url-suffix suffix] [-g/--github github] [--project project-name] [--theme theme] [-v/--verbose]
    """)
}

func main() 
{
    var arguments:[String] = .init(CommandLine.arguments.dropFirst().reversed())
    while let argument:String = arguments.popLast()
    {
        switch argument 
        {
        case "-d", "--directory":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            // remove trailing and doubled slashes 
            guard let head:Character = next.first 
            else 
            {
                // arguments strings should never be empty 
                fatalError("unreachable")
            }
            directory = "\(head)\(next.dropFirst().split(separator: "/").joined(separator: "/"))"
        
        case "-p", "--url-prefix":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            url.prefix = next 
        case "-s", "--url-suffix":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            // remove leading, trailing, and doubled slashes 
            url.suffix = "/\(next.split(separator: "/").joined(separator: "/"))"
        case "-g", "--github":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            github = next 
        case "--project":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            project = next 
        case "--theme":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            theme = next 
        case "-v", "--verbose":
            verbose = true 
         
        case "-h", "--help":
            help()
            return 
        default:
            sources.append(argument)
        }
    }

    pages(sources: sources, directory: directory, urlpattern: url, github: github, project: project ?? github, theme: theme, verbose: verbose)
}

main()
