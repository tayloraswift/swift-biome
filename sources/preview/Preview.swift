import BiomeIndex
import BiomeTemplates
import Resources
import HTML
import NIO
import NIOHTTP1
import SystemExtras

actor Preview
{
    struct Request:ExpressibleByPartialHTTPRequest, Sendable 
    {
        let uri:URI 
        
        init?(source _:SocketAddress?, head:HTTPRequestHead)
        {
            if let uri:URI = try? .init(absolute: head.uri)
            {
                self.uri = uri
            }
            else 
            {
                return nil 
            }
        }
    }
    
    private 
    var biome:Biome
    private 
    var resources:[String: Resource]
    
    init(projects:[FilePath], resources:FilePath) async throws 
    {
        self.resources = [:]
        self.biome = .init(roots: [.master: "reference", .article: "learn"], 
            template: .init(freezing: DefaultTemplates.documentation))
        
        var pins:[Package.ID: MaskedVersion] = [:]
        try self.loadBuiltinModules(pins: &pins, from: resources.appending("swift"))
        try self.loadProjects(projects, pins: pins)
        
        try self.loadResources(from: resources)
        
        self.resources["/biome.css"] = .init(
            hashing: try resources.appending(["css", "biome.css"]).read(), 
            type: .utf8(encoded: .css))
        self.resources["/search.js"] = .init(
            hashing: try resources.appending(["js", "main.js"]).read(), 
            type: .utf8(encoded: .javascript))
    }
    
    private  
    func loadResources(from directory:FilePath) throws 
    {
        try Task.checkCancellation()
        
        let fonts:[(external:String, internal:String)] = 
        [
            ("text-45", "Literata-Regular"),
            ("text-47", "Literata-RegularItalic"),
            ("text-65", "Literata-SemiBold"),
            ("text-67", "Literata-SemiBoldItalic"),
        ]
        try self.loadFonts(fonts, .ttf, .woff2, 
            from: directory.appending(["fonts", "Literata"]))
    }
    private  
    func loadFonts(_ fonts:[(external:String, internal:String)], _ types:MIME..., 
        from directory:FilePath) throws 
    {
        for name:(external:String, internal:String) in fonts 
        {
            for type:MIME in types 
            {
                let uri:String = "/\(name.external).\(type.extension)"
                let path:FilePath = directory.appending("\(name.internal).\(type.extension)")
                self.resources[uri] = .init(hashing: try path.read(), type: type)
            }
        }
    }
}
extension Preview 
{
    private 
    func loadBuiltinModules(pins:inout [Package.ID: MaskedVersion], 
        from directory:FilePath) throws 
    {
        try Task.checkCancellation() 
        
        // load standard library
        for version:Substring in try directory.appending("swift-versions").read()
            .split(whereSeparator: \.isWhitespace)
        {
            guard   let component:FilePath.Component = .init(String.init(version)), 
                    let version:MaskedVersion = .init(version)
            else 
            {
                continue 
            }
            let project:FilePath = directory.appending(component)
            let catalogs:[Package.Catalog] = 
                try .init(parsing: try project.appending("Package.catalog").read())
            
            pins = [.swift: version, .core: version]
            for catalog:Package.Catalog in catalogs
            {
                try self.biome.updatePackage(try catalog.loadGraph(relativeTo: project), 
                    era: pins)
            }
        }
    }
    private 
    func loadProjects(_ projects:[FilePath], pins:[Package.ID: MaskedVersion]) throws
    {
        for project:FilePath in projects 
        {
            try Task.checkCancellation() 
            
            print("loading project '\(project)'...")
            
            let resolved:Package.Resolved = 
                try .init(parsing: try project.appending("Package.resolved").read())
            let catalogs:[Package.Catalog] = 
                try .init(parsing: try project.appending("Package.catalog").read())
            let pins:[Package.ID: MaskedVersion] = pins.merging(resolved.pins) { $1 }
            for catalog:Package.Catalog in catalogs
            {
                try self.biome.updatePackage(try catalog.loadGraph(relativeTo: project), 
                    era: pins)
            }
        }
        
        self.biome.regenerateCaches()
    }
}

extension Preview 
{
    func serve(_ requests:AsyncStream<Request.Enqueued>) async 
    {
        for await (request, promise):Request.Enqueued in requests 
        {
            if let response:StaticResponse = self.biome[uri: request.uri]
            {
                promise.succeed(response)
                continue 
            }
            
            let uri:URI = .init(path: request.uri.path.normalized.components)
            if let resource:Resource = self.resources[uri.description]
            {
                if case nil = request.uri.query, uri ~= request.uri 
                {
                    promise.succeed(.matched(resource, 
                        canonical: uri.description))
                }
                else 
                {
                    promise.succeed(.found(at: uri.description, 
                        canonical: uri.description))
                }
            }
            else 
            {
                promise.succeed(.none(.init("page not found.")))
                continue 
            }
        }
    }
}
