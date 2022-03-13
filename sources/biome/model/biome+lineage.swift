extension Biome 
{
    /* struct Lineage:Hashable 
    {
        let package:Package.ID
        let graph:Graph
        let module:Int 
        let bystander:Int? 
        let path:[String]
        
        var last:String 
        {
            guard let last:String = path.last 
            else 
            {
                fatalError("unreachable")
            }
            return last 
        }
        
        var parent:Self? 
        {
            let path:ArraySlice = self.path.dropLast()
            if path.isEmpty 
            {
                return nil 
            }
            else 
            {
                return .init(package: self.package, graph: self.graph, 
                    module:     self.module, 
                    bystander:  self.bystander, 
                    path: [String].init(path))
            }
        }
        
        /* var lexemes:[SwiftLanguage.Lexeme<Symbol.ID>] 
        {
            var lexemes:[SwiftLanguage.Lexeme<Symbol.ID>] = []
                lexemes.reserveCapacity(self.path.count * 2 - 1)
            for current:String in self.path.dropLast() 
            {
                lexemes.append(.code(current,   class: .identifier))
                lexemes.append(.code(".",       class: .punctuation))
            }
            lexemes.append(.code(self.last,     class: .identifier))
            return lexemes
        } */
    } */

}
