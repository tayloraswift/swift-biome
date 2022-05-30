import Resource
import Biome 
import HTML 

public 
enum DefaultTemplates 
{
    public 
    typealias Element = HTML.Element<Page.Anchor>
    
    public static
    var documentation:DocumentRoot<HTML, Page.Anchor>
    {
        .init 
        {
            HTML.Lang.en
        }
        content:
        {
            Element[.head]
            {
                Element[.title]
                {
                    Element.anchor(id: .title)
                }
                Element.metadata(charset: Unicode.UTF8.self)
                Element.metadata 
                {
                    ("viewport", "width=device-width, initial-scale=1")
                }
                
                Element[.script]
                {
                    Element.anchor(id: .constants)
                }
                Element[.script]
                {
                    ("/search.js", as: HTML.Src.self)
                    (true, as: HTML.Defer.self)
                }
                
                Element[.link]
                {
                    ("/biome.css", as: HTML.Href.self)
                    HTML.Rel.stylesheet
                }
                Element[.link]
                {
                    ("/favicon.png", as: HTML.Href.self)
                    HTML.Rel.icon
                }
                Element[.link]
                {
                    ("/favicon.ico", as: HTML.Href.self)
                    HTML.Rel.icon
                    Resource.Binary.icon
                }
            }
            Element[.body]
            {
                ["documentation"]
            }
            content: 
            {
                Element[.nav]
                {
                    Element[.div]
                    {
                        ["breadcrumbs"]
                    } 
                    content: 
                    {
                        Element.anchor(id: .navigator)
                    }
                    Element[.div]
                    {
                        ["search-bar"]
                    } 
                    content: 
                    {
                        Element[.form] 
                        {
                            HTML.Role.search
                            ("search", as: HTML.ID.self)
                        }
                        content: 
                        {
                            Element[.div]
                            {
                                ["input-container"]
                            }
                            content: 
                            {
                                Element[.div]
                                {
                                    ["bevel"]
                                }
                                Element[.div]
                                {
                                    ["rectangle"]
                                }
                                content: 
                                {
                                    Element[.input]
                                    {
                                        ("search-input", as: HTML.ID.self)
                                        HTML.InputType.search
                                        HTML.Autocomplete.off
                                        // (true, as: HTML.Autofocus.self)
                                        ("search symbols", as: HTML.Placeholder.self)
                                    }
                                }
                                Element[.div]
                                {
                                    ["bevel"]
                                }
                            }
                            Element[.ol]
                            {
                                ("search-results", as: HTML.ID.self)
                            }
                        }
                    }
                }
                Element[.main]
                {
                    Element[.div]
                    {
                        ["upper"]
                    }
                    content: 
                    {
                        Element[.div]
                        {
                            ["upper-container"]
                        }
                        content: 
                        {
                            Element[.article]
                            {
                                ["upper-container-left"]
                            }
                            content: 
                            {
                                //Element.anchor(id: .introduction)
                                
                                Element[.section]
                                {
                                    ["introduction"]
                                }
                                content:
                                {
                                    Element[.div]
                                    {
                                        ["eyebrows"]
                                    }
                                    content:
                                    {
                                        Element[.span]
                                        {
                                            ["kind"]
                                        }
                                        content: 
                                        {
                                            Element.anchor(id: .kind)
                                        }
                                        
                                        Element[.span]
                                        {
                                            ["nationality"]
                                        }
                                        content: 
                                        {
                                            Element.anchor(id: .metropole)
                                            Element.anchor(id: .colony)
                                        }
                                    }
                                    
                                    Element.anchor(id: .headline)
                                    
                                    Element.anchor(id: .summary)
                                    
                                    Element.anchor(id: .relationships)
                                    Element.anchor(id: .availability)
                                }
                                
                                Element.anchor(id: .platforms)
                                Element.anchor(id: .declaration)
                                
                                Element.anchor(id: .introduction)
                                Element.anchor(id: .discussion)
                            }
                        }
                    }
                    Element[.div]
                    {
                        ["lower"]
                    }
                    content: 
                    {
                        Element.anchor(id: .dynamic)
                    }
                }
            }
        }
    }
}
