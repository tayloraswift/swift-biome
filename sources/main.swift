import ArgumentParser

struct Entrapta:ParsableCommand 
{
    @Argument(help: "The list of source files to extract documentation comments from.")
    var sources:[String] = []
    
    @Option(name: [.customShort("d"), .customLong("directory")], help: 
        """
        The directory to emit generated documentation pages to.
        """)
    var directory:String = "documentation"
    
    @Option(name: [.customShort("p"), .customLong("url-prefix")], help: 
        """
        The prefix to append to all generated links. \
        this may need to be different from <directory> when deploying to github pages.
        """)
    var urlPrefix:String 
    
    @Option(name: [.customShort("g"), .customLong("github")], help: 
        """
        The url to a github repository for this project.
        """)
    var github:String = "https://github.com"
    
    @Option(name: [.customLong("title")], help: 
        """
        The html title to display on the generated documentation pages.
        """)
    var title:String = "API Documentation"
    
    @Option(name: [.customLong("theme")], help: 
        """
        The css theme to use.
        """)
    var theme:String = "eternia"
    
    @Flag(name: [.customShort("v"), .customLong("verbose")], help: 
        """
        Enable verbose output.
        """)
    var verbose:Bool = false 
    
    @Flag(name: [.customShort("l"), .customLong("local")], help: 
        """
        Configure generated links to reference other generated documentation pages \ 
        in the local file system.
        """)
    var local:Bool = false 
    
    // removes trailing slashes 
    private static 
    func normalize(path:String) -> String 
    {
        // preserve leading slash, if present 
        guard let head:Character = path.first 
        else 
        {
            fatalError("unreachable")
        }
        var tail:Substring = path.dropFirst()
        while tail.last == "/"
        {
            tail.removeLast()
        }
        return "\(head)\(tail)"
    }
    
    func run() 
    {
        var doccomments:[String] = [] 
        for source:String in self.sources 
        {
            guard let contents:String = File.source(path: source) 
            else 
            {
                print("error: could not open source file '\(source)'") 
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
        
        let pages:[Page] = doccomments.enumerated().compactMap
        {
            let (i, doccomment):(Int, String) = $0
            do 
            {
                let parsed:[Grammar.Field]  =     .init(parsing: doccomment), 
                    fields:Page.Fields      = try .init(parsed.dropFirst())
                
                switch parsed.first 
                {
                case .framework (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .dependency(let header)?:
                    return try .init(header, fields: fields, order: i)
                case .lexeme    (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .subscript (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .function  (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .property  (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .typealias (let header)?:
                    return try .init(header, fields: fields, order: i)
                case .type      (let header)?:
                    return try .init(header, fields: fields, order: i)
                default:
                    throw Entrapta.Error.init("could not parse doccomment")
                }
            }
            catch let error as Entrapta.Error 
            {
                print("\(error)")
                print(
                    """
                    note: while parsing doccomment 
                    '''
                    \(doccomment)
                    '''
                    """)
                return nil 
            }
            catch 
            {
                return nil 
            }
        }
        
        InternalNode.tree(pages)
        {
            (root:InternalNode) in 
            
            // print out root 
            if self.verbose 
            {
                print(root)
            }
            
            let normalized:(prefix:String, directory:String) = 
            (
                Self.normalize(path: self.urlPrefix),
                Self.normalize(path: self.directory)
            )
            
            func url(_ path:[String]) -> String 
            {
                ([normalized.prefix] + path + (self.local ? ["index.html"] : []))
                .joined(separator: "/")
            }
            
            root.postprocess(urlGenerator: url)
            
            guard   let fonts:String = File.source(path: "themes/\(self.theme)/fonts"),
                    let css:String   = File.source(path: "themes/\(self.theme)/style.css") 
            else 
            {
                fatalError("failed to load theme '\(self.theme)'") 
            }
            
            for page:Page in root.allPages
            {
                guard case .local(url: _, directory: let directory) = page.anchor 
                else 
                {
                    continue
                }
                let path:[String]   = [normalized.directory] + directory
                let document:String = 
                """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                \(fonts)
                    <link href="\(normalized.prefix)/style.css" rel="stylesheet"> 
                    <title>\(page.name) - \(self.title)</title>
                </head> 
                <body>
                    \(page.html(github: self.github).rendered)
                </body>
                </html>
                """
                File.pave(path)
                File.save(.init(document.utf8), path: (path + ["index.html"]).joined(separator: "/"))
            }
            
            // create 404 page 
            let notfound:String = 
            """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
            \(fonts)
                <link href="\(normalized.prefix)/style.css" rel="stylesheet"> 
                <title>Page not found - \(self.title)</title>
            </head> 
            <body>
                <main>
                    <nav>
                        <div class="navigation-container">
                            <ul><li class="github-icon-container"><a href="\(self.github)"><span class="github-icon" title="Github repository"></span></a></li></ul>
                        </div>
                    </nav>
                    <section class="introduction">
                        <div class="section-container error-404-message">
                            <h1 class="topic-heading">query not recognized</h1>
                            <p>What is your query?</p>
                            <p><a href="\(url([]))">Go to documentation root</a></p>
                        </div>
                    </section>
                </main>
            </body>
            </html>
            """
            File.save(.init(notfound.utf8), path: "\(normalized.directory)/404.html")
            
            // emit stylesheet 
            File.save(.init(css.utf8), path: "\(normalized.directory)/style.css")
            // copy github-icon.svg 
            guard let icon:String = File.source(path: "themes/github-icon.svg") 
            else 
            {
                fatalError("missing github icon") 
            }
            File.save(.init(icon.utf8), path: "\(normalized.directory)/github-icon.svg") 
        }
    }
}

Entrapta.main()
