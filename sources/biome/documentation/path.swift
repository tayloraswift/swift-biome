/* import Grammar

extension Biome 
{
    @available(*, deprecated)
    public 
    struct Path:Hashable, Sendable
    {
        let group:String
        var disambiguation:Symbol.ID?
        
        @available(*, unavailable, renamed: "description")
        var uri:String 
        {
            self.description 
        }
        @available(*, deprecated, renamed: "description")
        var canonical:String 
        {
            self.description 
        }
        var description:String 
        {
            if let id:Symbol.ID = self.disambiguation 
            {
                return "\(self.group)?overload=\(id.usr)"
            }
            else 
            {
                return self.group
            }
        }
        init(group:String, disambiguation:Symbol.ID? = nil)
        {
            self.group          = group
            self.disambiguation = disambiguation
        }
        init(prefix:[String], disambiguation:Symbol.ID)
        {
            self.init(group: Self.normalize(lowercasing: prefix), disambiguation: disambiguation)
        }
        init(prefix:[String], package:Package.ID, suffix:String...) 
        {
            var unescaped:[String] = prefix 
            unescaped.append(package.name)
            unescaped.append(contentsOf: suffix)
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
        init(prefix:[String], package:Package.ID, namespace:Module.ID) 
        {
            var unescaped:[String] = prefix 
            if case .community(let package) = package 
            {
                unescaped.append(package)
            }
            unescaped.append(namespace.title)
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
        init(prefix:[String], _ lineage:Lineage, dot:Bool) 
        {
            self.init(prefix: prefix, 
                package: lineage.package, 
                namespace: lineage.graph.namespace, 
                path: lineage.path, 
                dot: dot)
        }
        init(prefix:[String], package:Package.ID, namespace:Module.ID, path:[String], dot:Bool) 
        {
            // to reduce the need for disambiguation suffixes, nested types and members 
            // use different syntax: 
            // Foo.Bar.baz(qux:) -> 'foo/bar.baz(qux:)' ["foo", "bar.baz(qux:)"]
            // 
            // global variables, functions, and operators (including scoped operators) 
            // start with a slash. so it’s 'prefix/swift/withunsafepointer(to:)', 
            // not `prefix/swift.withunsafepointer(to:)`
            var unescaped:[String]  = prefix 
            if case .community(let package) = package 
            {
                unescaped.append(package)
            }
            unescaped.append(namespace.title)
            if  dot, 
                let last:String     = path.last,
                let scope:String    = path.dropLast().last 
            {
                unescaped.append(contentsOf: path.dropLast(2))
                unescaped.append("\(scope).\(last)")
            }
            else 
            {
                unescaped.append(contentsOf: path)
            }
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
    }
} */
