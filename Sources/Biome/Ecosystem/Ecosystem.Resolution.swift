import SymbolGraphs
import Versions
import Resources
import DOM
import URI

extension Ecosystem 
{
    enum Redirect
    {
        case index(Index, pins:Package.Pins, template:DOM.Flattened<Page.Key>? = nil)
        case resource(Resource)
    }
    
    @usableFromInline
    enum Resolution
    {
        case index(Index, pins:Package.Pins, exhibit:Version? = nil, template:DOM.Flattened<Page.Key>? = nil)
        
        case choices([Composite], pins:Package.Pins)
        case resource(Resource, uri:URI)
    }
    
    @usableFromInline
    func resolve(path:[String], query:[URI.Parameter]) 
        -> (resolution:Resolution, redirected:Bool)?
    {
        if  let root:String = path.first, 
            let root:Route.Stem = self.stems[leaf: root],
            let root:Root = self.roots[root],
            case let (resolution, redirected)? = self.resolve(root: root,
                path: path.dropFirst(), 
                query: query) 
        {
            return (resolution, redirected)
        }
        else 
        {
            return nil 
        }
    }
    
    private 
    func resolve<Path>(root:Root, path:Path, query:[URI.Parameter]) 
        -> (resolution:Resolution, redirected:Bool)?
        where Path:BidirectionalCollection, Path.Element:StringProtocol
    {
        switch root 
        {
        case .sitemap: 
            guard   let components:[Path.Element.SubSequence] = path.first?.split(separator: "."),
                    let package:Package.ID = components.first.map(Package.ID.init(_:)), 
                    let package:Packages.Index = self.packages.index[package], 
                    let sitemap:Resource = self.caches[package]?.sitemap
            else 
            {
                return nil 
            }
            return (.resource(sitemap, uri: self.uriOfSiteMap(for: package)), false) 
        
        case .searchIndex: 
            guard   let package:Package.ID = path.first.map(Package.ID.init(_:)), 
                    let package:Packages.Index = self.packages.index[package],
                    case "types"? = path.dropFirst().first, 
                    let search:Resource = self.caches[package]?.search
            else 
            {
                return nil 
            }
            return (.resource(search, uri: self.uriOfSearchIndex(for: package)), false) 
        
        case .article: 
            fatalError("obsoleted")
        
        case .master:
            fatalError("obsoleted")
        }
    }
}
