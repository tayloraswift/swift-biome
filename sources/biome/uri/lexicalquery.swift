import Grammar

struct LexicalQuery 
{
    typealias Parameter = 
    (
        key:String, 
        value:String
    )
    
    var witness:Symbol.ID?
    var victim:Symbol.ID?
    
    init(normalizing parameters:[Parameter]) throws 
    {
        self.witness = nil
        self.victim = nil
        
        for (key, value):(String, String) in parameters 
        {
            switch key
            {
            case "self":
                // if the mangled name contained a colon ('SymbolGraphGen style'), 
                // the parsing rule will remove it.
                self.victim  = try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.OpaqueName.self)
            
            case "overload": 
                switch         try Grammar.parse(value.utf8, as: Symbol.USR.Rule<String.Index>.self) 
                {
                case .natural(let witness):
                    self.witness = witness
                
                case .synthesized(from: let witness, for: let victim):
                    // this is supported for backwards-compatibility, 
                    // but the `::SYNTHESIZED::` infix is deprecated, 
                    // so this will end up causing a redirect 
                    self.witness = witness 
                    self.victim  = victim
                }

            default: 
                continue  
            }
        }
    }
}
