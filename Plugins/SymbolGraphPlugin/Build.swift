import PackagePlugin

struct Build
{
    var cultures:[String]
    var snippets:[String]

    init() 
    {
        self.cultures = []
        self.snippets = []
    }

    mutating 
    func append(culture target:SwiftSourceModuleTarget, 
        dependencies:[Package.ID: [SwiftSourceModuleTarget]], 
        include:[String])
    {
        let object:String =
        """
        
                    {
                        "id": "\(target.name)",
                        "dependencies": [\(dependencies.sorted { $0.key < $1.key }.map 
                        { 
                            """
                            {"package": "\($0.key)", "modules": [\($0.value.lazy.map(\.name)
                                .sorted().map { "\"\($0)\"" }.joined(separator: ", "))]}
                            """
                        }.joined(separator: ", "))],
                        "include": 
                        [\(include.sorted().map 
                        { 
                            """
                            
                                                "\($0)"
                            """
                        }.joined(separator: ", "))
                        ]
                    }
        """
        self.cultures.append(object)
    }

    mutating 
    func append(snippet target:SwiftSourceModuleTarget, 
        dependencies:[Package.ID: [SwiftSourceModuleTarget]], 
        sources:[String])
    {
        let object:String =
        """
        
                    {
                        "id": "\(target.name)",
                        "dependencies": [\(dependencies.sorted { $0.key < $1.key }.map 
                        { 
                            """
                            {"package": "\($0.key)", "modules": [\($0.value.lazy.map(\.name)
                                .sorted().map { "\"\($0)\"" }.joined(separator: ", "))]}
                            """
                        }.joined(separator: ", "))],
                        "sources": 
                        [\(sources.sorted().map 
                        { 
                            """
                            
                                                "\($0)"
                            """
                        }.joined(separator: ", "))
                        ]
                    }
        """
        self.snippets.append(object)
    }
}