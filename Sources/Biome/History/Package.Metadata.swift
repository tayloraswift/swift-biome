extension Package 
{
    enum MetadataLoadingError:Error 
    {
        case article
        case module
        case symbol
        case foreign
    }

    // struct Metadata 
    // {
    //     private(set)
    //     var articles:History<Article.Metadata?>,
    //         modules:History<Module.Metadata?>, 
    //         symbols:History<Symbol.Metadata?>, 
    //         foreign:History<Symbol.ForeignMetadata?>

    //     init() 
    //     {
    //         self.articles = .init()
    //         self.modules = .init()
    //         self.symbols = .init()
    //         self.foreign = .init()
    //     }
    // }
}

// extension Package.Metadata 
// {

// }