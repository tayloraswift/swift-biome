extension Article:BranchElement
{
    struct Headline:Equatable, Sendable
    {
        let formatted:String
        let plain:String 

        init(formatted:String, plain:String)
        {
            self.formatted = formatted 
            self.plain = plain 
        }

        init(markup:__shared Extension.Headline)
        {
            self.init(formatted: .init(decoding: markup.rendered(as: [UInt8].self), 
                    as: Unicode.UTF8.self), 
                plain: markup.plainText)
        }
    }
    struct Metadata:Equatable, Sendable
    {
        let headline:Headline 
        let excerpt:String 

        init(headline:Headline, excerpt:String = "")
        {
            self.headline = headline 
            self.excerpt = excerpt
        }
        init(_extension:__shared Extension)
        {
            self.headline = .init(markup: _extension.headline)
            self.excerpt = _extension.snippet
        }
    }

    @usableFromInline 
    struct Divergence:Voidable, Sendable
    {
        var metadata:_History<Metadata?>.Divergent?
    }
    

    struct Excerpt:Equatable 
    {
        let title:String
        let headline:[UInt8]
        let snippet:String
        
        init(_ title:String)
        {
            self.init(title: title, headline: .init(title.utf8), snippet: "")
        }
        init(title:String, headline:[UInt8], snippet:String)
        {
            self.headline = headline 
            self.snippet = snippet
            self.title = title 
        }
    }
}
