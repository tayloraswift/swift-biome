@_exported import Biome 
import VersionControl
import JSON

extension Package 
{
    public 
    struct Resolved
    {
        // needed for compatibility with older spm tools
        struct Legacy:Decodable
        {
            let object:Object
        }
        struct Object:Decodable 
        {
            struct State:Decodable 
            {
                let revision:String, 
                    version:String?, 
                    branch:String?
            }
            struct Pin:Decodable 
            {
                let id:ID?, 
                    package:ID?,
                    location:String?, 
                    state:State 
                    
                enum CodingKeys:String, CodingKey 
                {
                    case id = "identity" 
                    case package 
                    case location 
                    case state 
                }
            }
            
            let pins:[Pin]
        }
        
        public
        var pins:[ID: MaskedVersion]
        
        public
        init(parsing file:[UInt8]) throws 
        {
            let json:JSON = try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            if  let object:Object = try? .init(from: json)
            {
                self.init(pins: object.pins)
            }
            else 
            {
                let wrapper:Legacy = try .init(from: json)
                self.init(pins: wrapper.object.pins)
            }
        }
        init(pins:[Object.Pin])
        {
            self.pins = [:]
            for pin:Object.Pin in pins 
            {
                guard let id:ID = pin.id ?? pin.package 
                else 
                {
                    continue 
                }
                // these strings are slightly different from the ones we 
                // parse from url queries 
                if let string:String = pin.state.version
                {
                    // always 3 components 
                    let numbers:[Substring] = string.split(separator: ".")
                    if  numbers.count == 3, 
                        let major:UInt16 = .init(numbers[0]),
                        let minor:UInt16 = .init(numbers[1]),
                        let patch:UInt16 = .init(numbers[2])
                    {
                        self.pins[id] = .patch(major, minor, patch)
                    }
                }
                else if let string:String = pin.state.branch
                {
                    let words:[Substring] = string.split(separator: "-")
                    if  words.count == 7, 
                        words[0] == "swift", 
                        words[1] == "DEVELOPMENT", 
                        words[2] == "SNAPSHOT", 
                        let year:UInt16 = .init(words[3]), 
                        let month:UInt16 = .init(words[4]), 
                        let day:UInt16 = .init(words[5]), 
                        let letter:Unicode.Scalar = words[6].unicodeScalars.first,
                        "a" ... "z" ~= letter
                    {
                        self.pins[id] = .date(year: year, month: month, day: day, 
                            letter: .init(ascii: letter))
                    }
                }
            }
        }
    }
    public 
    struct Descriptor:Decodable 
    {
        public
        enum CodingKeys:String, CodingKey 
        {
            case id             = "package" 
            case modules        = "modules"
            case toolsVersion   = "catalog_tools_version"
        }
        
        public
        let id:ID
        public
        let modules:[Module.Descriptor]
        let toolsVersion:Int
        
        static 
        let toolsVersion:Int = 2
        
        public 
        init(id:ID, modules:[Module.Descriptor])
        {
            self.id = id 
            self.modules = modules
            self.toolsVersion = Self.toolsVersion
        }
        
        public 
        func load(with controller:VersionController?) 
            async throws -> Package.Catalog
        {
            guard self.toolsVersion == Self.toolsVersion
            else 
            {
                fatalError("version mismatch")
            }
            var modules:[Module.Catalog] = []
            for module:Module.Descriptor in self.modules 
            {
                modules.append(try await module.load(with: controller))
            }
            return .init(id: self.id, modules: modules)
        }
    }
    
    public static 
    func descriptors(parsing file:[UInt8]) throws -> [Descriptor]
    {
        try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self).map(Descriptor.init(from:))
    }
}
extension Module 
{
    public 
    struct Descriptor:Decodable 
    {
        public
        let id:ID
        var include:[String] 
        var dependencies:[Graph.Dependency]
        
        public 
        enum CodingKeys:String, CodingKey 
        {
            case id = "module" 
            case include 
            case dependencies
        }
        
        public 
        init(id:ID, include:[String], dependencies:[Graph.Dependency])
        {
            self.id = id 
            self.include = include 
            self.dependencies = dependencies
        }
        
        func load(with controller:VersionController? = nil) async throws -> Catalog
        {
            var locations:
            (
                articles:[(name:String, source:FilePath)],
                colonies:[(namespace:ID, graph:FilePath)],
                core:FilePath?
            )
            locations.articles = []
            locations.colonies = []
            locations.core = nil
            for include:FilePath in self.include.map(FilePath.init(_:))
            {
                // if the include path is relative, and we are using a version controller, 
                // prepend the repository base to the path.
                let root:FilePath 
                if let prefix:FilePath = controller?.repository 
                {
                    root = include.isAbsolute ? include : prefix.appending(include.components)
                }
                else 
                {
                    root = include
                }
                
                root.walk
                {
                    (path:FilePath) in 
                    
                    guard let file:FilePath.Component = path.components.last 
                    else 
                    {
                        return 
                    }
                    // this is *relative* if `include` was relative
                    let location:FilePath = include.appending(path.components)
                    switch file.extension
                    {
                    case "md"?:
                        locations.articles.append((file.stem, location))
                    
                    case "json"?:
                        guard   let reduced:FilePath.Component = .init(file.stem),
                                case "symbols"? = reduced.extension
                        else 
                        {
                            break 
                        }
                        let identifiers:[Substring] = reduced.stem.split(separator: "@", omittingEmptySubsequences: false)
                        guard case self.id? = identifiers.first.map(ID.init(_:))
                        else 
                        {
                            print("warning: ignored symbolgraph with invalid name '\(reduced.stem)'")
                            break 
                        }
                        switch (identifiers.count, locations.core)
                        {
                        case (1, nil): 
                            locations.core = location
                        case (1, _?):
                            print("warning: ignored duplicate symbolgraph '\(reduced.stem)'")
                        case (2, _):
                            locations.colonies.append((ID.init(identifiers[1]), location))
                        default: 
                            return
                        }
                        
                    default: 
                        break
                    }
                }
            }
            
            func load(_ path:FilePath, _ type:Resource.Text) async throws -> Resource 
            {
                try await controller?.read(from: path, type: type) ?? .utf8(encoded: File.read(from: path), type: type)
            }
            
            let core:Resource
            if let location:FilePath = locations.core 
            {
                core = try await load(location, .json)
            }
            else 
            {
                throw GraphError.missing(id: self.id)
            }
            var colonies:[(ID, Resource)] = []
                colonies.reserveCapacity(locations.colonies.count)
            for (namespace, location):(ID, FilePath) in locations.colonies 
            {
                colonies.append((namespace, try await load(location, .json)))
            }
            var articles:[(String, Resource)] = []
                articles.reserveCapacity(locations.articles.count)
            for (name, location):(String, FilePath) in locations.articles 
            {
                articles.append((name, try await load(location, .markdown)))
            }
            return .init(id: self.id, core: core, colonies: colonies, articles: articles, 
                dependencies: self.dependencies)
        }
    }
}
