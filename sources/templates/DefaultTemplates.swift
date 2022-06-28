import Resource
import Biome 
import HTML 

public 
enum DefaultTemplates 
{
    typealias Element = HTML.Element<Page.Key>
    
    public static
    func documentation<Stylesheets>(stylesheets:Stylesheets) -> HTML.Root<Page.Key>
        where Stylesheets:Sequence, Stylesheets.Element == String
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
                for stylesheet:String in stylesheets 
                {
                    Element[.link]
                    {
                        ("href",    stylesheet)
                        ("rel",     "stylesheet")
                    }
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
                Element[.header]
                {
                    Element[.nav]
                    {
                        ("class", "breadcrumbs")
                    } 
                    content: 
                    {
                        Element.anchor(.breadcrumbs)
                    }
                    
                    Element[.div]
                    {
                        ("class", "toolbar-container")
                    } 
                    content: 
                    {
                        Element[.div]
                        {
                            ("class", "toolbar")
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
                                Element[.input]
                                {
                                    ("id",              "search-input")
                                    ("type",            "search")
                                    ("placeholder",     "search symbols")
                                    ("autocomplete",    "off")
                                }
                            }
                            Element[.nav]
                            {
                                ("class", "versions")
                            }
                            content: 
                            {
                                Element[.input]
                                {
                                    ("id",      "version-menu-input")
                                    ("type",    "checkbox")
                                }
                                Element[.label]
                                {
                                    ("for",     "version-menu-input")
                                }
                                content: 
                                {
                                    Element.anchor(.pin)
                                }
                                Element.anchor(.versions)
                            }
                        }
                        Element[.ol]
                        {
                            ("id", "search-results")
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
                                            Element.anchor(.namespace)
                                            Element.anchor(.culture)
                                            Element.anchor(.base)
                                        }
                                    }
                                    
                                    Element.anchor(.headline)
                                    
                                    Element.anchor(.summary)
                                    
                                    Element.anchor(.notes)
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
                        Element.anchor(.topics)
                    }
                }
            }
        }
    }
}