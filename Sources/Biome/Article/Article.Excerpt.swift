extension Article 
{
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
