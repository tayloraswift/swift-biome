extension Biome 
{
    public 
    struct Path:Hashable, Sendable
    {
        let group:String
        var disambiguation:Symbol.ID?
        
        var canonical:String 
        {
            if let id:Symbol.ID = self.disambiguation 
            {
                return "\(self.group)?overload=\(id.string)"
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
        init(prefix:[String], package:String?, namespace:Module.ID) 
        {
            var unescaped:[String]  = prefix 
            if  let package:String  = package 
            {
                unescaped.append(package)
            }
            unescaped.append(namespace.title)
            self.init(group: Biome.normalize(path: unescaped))
        }
        init(prefix:[String], _ breadcrumbs:Breadcrumbs, dot:Bool) 
        {
            self.init(prefix: prefix, 
                package: breadcrumbs.package, 
                namespace: breadcrumbs.graph.namespace, 
                path: breadcrumbs.path, 
                dot: dot)
        }
        init(prefix:[String], package:String?, namespace:Module.ID, path:[String], dot:Bool) 
        {
            // to reduce the need for disambiguation suffixes, nested types and members 
            // use different syntax: 
            // Foo.Bar.baz(qux:) -> 'foo/bar.baz(qux:)' ["foo", "bar.baz(qux:)"]
            // 
            // global variables, functions, and operators (including scoped operators) 
            // start with a slash. so it’s 'prefix/swift/withunsafepointer(to:)', 
            // not `prefix/swift.withunsafepointer(to:)`
            var unescaped:[String]  = prefix 
            if  let package:String  = package 
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
            self.init(group: Biome.normalize(path: unescaped))
        }
    }
}
