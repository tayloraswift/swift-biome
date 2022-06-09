import Resource
import Biome 
import HTML 

public 
enum DefaultTemplates 
{
    typealias Element = HTML.Element<Page.Anchor>
    
    public static
    var documentation:HTML.Root<Page.Anchor>
    {
        .init 
        {
            ("lang", "en")
        }
        content:
        {
            Element[.head]
            {
                Element[.title]
                {
                    Element.anchor(.title)
                }
                
                Element[.meta]
                {
                    ("charset", "UTF-8")
                }
                Element[.meta]
                {
                    ("name",    "viewport")
                    ("content", "width=device-width, initial-scale=1")
                }
                
                Element[.script]
                {
                    Element.anchor(.constants)
                }
                Element[.script]
                {
                    ("src",     "/search.js")
                    ("defer",   true)
                }
                
                Element[.link]
                {
                    ("href",    "/biome.css")
                    ("rel",     "stylesheet")
                }
                Element[.link]
                {
                    ("href",    "/favicon.png")
                    ("rel",     "icon")
                }
                Element[.link]
                {
                    ("href",    "/favicon.ico")
                    ("rel",     "icon")
                    ("type",    Resource.Binary.icon.rawValue)
                }
            }
            Element[.body]
            {
                ("class", "documentation")
            }
            content: 
            {
                Element[.nav]
                {
                    Element[.div]
                    {
                        ("class", "breadcrumbs")
                    } 
                    content: 
                    {
                        Element.anchor(.navigator)
                    }
                    Element[.div]
                    {
                        ("class", "search-bar")
                    } 
                    content: 
                    {
                        Element[.form] 
                        {
                            ("role",    "search")
                            ("id",      "search")
                        }
                        content: 
                        {
                            Element[.div]
                            {
                                ("class", "input-container")
                            }
                            content: 
                            {
                                Element[.div]
                                {
                                    ("class", "bevel")
                                }
                                Element[.div]
                                {
                                    ("class", "rectangle")
                                }
                                content: 
                                {
                                    Element[.input]
                                    {
                                        ("id",              "search-input")
                                        ("type",            "search")
                                        ("placeholder",     "search symbols")
                                        ("autocomplete",    "off")
                                    }
                                }
                                Element[.div]
                                {
                                    ("class", "bevel")
                                }
                            }
                            Element[.ol]
                            {
                                ("id", "search-results")
                            }
                        }
                    }
                }
                Element[.main]
                {
                    Element[.div]
                    {
                        ("class", "upper")
                    }
                    content: 
                    {
                        Element[.div]
                        {
                            ("class", "upper-container")
                        }
                        content: 
                        {
                            Element[.article]
                            {
                                ("class", "upper-container-left")
                            }
                            content: 
                            {
                                Element[.section]
                                {
                                    ("class", "introduction")
                                }
                                content:
                                {
                                    Element[.div]
                                    {
                                        ("class", "eyebrows")
                                    }
                                    content:
                                    {
                                        Element[.span]
                                        {
                                            ("class", "kind")
                                        }
                                        content: 
                                        {
                                            Element.anchor(.kind)
                                        }
                                        
                                        Element[.span]
                                        {
                                            ("class", "nationality")
                                        }
                                        content: 
                                        {
                                            Element.anchor(.metropole)
                                            Element.anchor(.colony)
                                        }
                                    }
                                    
                                    Element.anchor(.headline)
                                    
                                    Element.anchor(.summary)
                                    
                                    Element.anchor(.relationships)
                                    Element.anchor(.availability)
                                }
                                
                                Element.anchor(.platforms)
                                Element.anchor(.fragments)
                                
                                Element.anchor(.introduction)
                                Element.anchor(.discussion)
                            }
                        }
                    }
                    Element[.div]
                    {
                        ("class", "lower")
                    }
                    content: 
                    {
                        Element.anchor(.dynamic)
                    }
                }
            }
        }
    }
}
