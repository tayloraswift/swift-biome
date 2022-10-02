import PackageResolution
import SymbolGraphs
import SymbolSource
import Versions

public 
struct Packages
{
    private 
    var packages:[Package]
    private(set)
    var index:[PackageIdentifier: Index]
    
    init()
    {
        self.packages = []
        self.index = [:]

        // swift-standard-library is always index = 0
        // swift-core-libraries is always index = 1
        let swift:Index = self.addPackage(.swift)
        let core:Index = self.addPackage(.core)

        precondition(swift == .swift) 
        precondition(core == .core) 
    }
}
extension Packages
{
    /// Creates a package entry for the given package graph, if it does not already exist.
    /// 
    /// -   Returns: The index of the package, identified by its ``PackageIdentifier``.
    mutating 
    func addPackage(_ package:PackageIdentifier) -> Index
    {
        if let index:Index = self.index[package]
        {
            return index 
        }
        else 
        {
            let index:Index = self.endIndex
            self.packages.append(.init(id: package, nationality: index))
            self.index[package] = index
            return index
        }
    }
}
extension Packages:RandomAccessCollection
{
    public 
    var startIndex:Index
    {
        .init(offset: .init(self.packages.startIndex))
    }
    public 
    var endIndex:Index
    {
        .init(offset: .init(self.packages.endIndex))
    }
    public 
    subscript(package:Index) -> Package
    {
        _read 
        {
            yield  self.packages[.init(package.offset)]
        }
        _modify 
        {
            yield &self.packages[.init(package.offset)]
        }
    } 
}
extension Packages 
{
    var swift:Package 
    {
        _read 
        {
            yield self[.swift]
        }
    }
    var core:Package 
    {
        _read 
        {
            yield self[.core]
        }
    }
    
    subscript(package:PackageIdentifier) -> Package?
    {
        self.index[package].map { self[$0] }
    }
    

    subscript(global module:Atom<Module>.Position) -> Module
    {
        _read 
        {
            yield self[module.nationality].tree[local: module]
        }
    } 
    subscript(global article:Atom<Article>.Position) -> Article
    {
        _read 
        {
            yield self[article.nationality].tree[local: article]
        }
    } 
    subscript(global symbol:Atom<Symbol>.Position) -> Symbol
    {
        _read 
        {
            yield self[symbol.nationality].tree[local: symbol]
        }
    } 
}
extension Packages
{
    func find(pins:some Sequence<PackageResolution.Pin>) 
        -> [Index: PackageUpdateContext.Dependency]
    {
        var linkable:[Index: PackageUpdateContext.Dependency] = [:]
        for pin:PackageResolution.Pin in pins 
        {
            guard   let package:Package = self[pin.id],
                    let tag:Tag = .init(pin.requirement)
            else 
            {
                continue 
            }
            if  let version:Version = package.tree.find(tag),
                    package.tree[version].commit.hash == pin.revision
            {
                linkable[package.nationality] = .available(version)
            }
            else 
            {
                linkable[package.nationality] = .unavailable(tag, pin.revision)
            }
        }
        return linkable
    }
}
extension Packages 
{
    /// Returns the index of the package referenced by the given identifier, and 
    /// the fork location within it, if a fork selector is provided.
    /// 
    /// This method will only create package descriptors if `fork` is [`nil`]().
    // private mutating 
    // func add(package id:PackageIdentifier, fork:Version.Selector?) -> (Index, Version?)
    // {
    //     if  let fork:Version.Selector 
    //     {
    //         guard   let package:Index = self.index[id], 
    //                 let fork:Version = self[package].tree.find(fork)
    //         else 
    //         {
    //             fatalError("couldn’t find tag to fork from")
    //         }
    //         // guard case fork.revision? = self[package].tree[fork.branch].head 
    //         // else 
    //         // {
    //         //     // we can relax this restriction once we have a way of persisting 
    //         //     // API surfaces for revisions besides the branch head 
    //         //     fatalError("can only fork from branch head (for now)")
    //         // }
    //         return (package, fork)
    //     }
    //     else 
    //     {
    //         return (self.add(package: id), nil)
    //     }
    // }
    

    // private mutating
    // func commit(_ revision:String, 
    //     to branch:Version.Branch, 
    //     of nationality:Index, 
    //     interfaces:[ModuleInterface], 
    //     date:Date, 
    //     tag:Tag?) -> Version
    // {
    //     var pins:[Index: (version:Version, consumers:Set<Atom<Module>>)] = [:]
    //     for interface:ModuleInterface in interfaces 
    //     {
    //         for (package, pin):(Index, Version) in interface.pins 
    //         {
    //             pins[package, default: (pin, [])].consumers.insert(interface.culture)
    //         }
    //     }
    //     let version:Version = self[nationality].tree.commit(branch: branch, hash: revision, 
    //         pins: pins.mapValues(\.version), 
    //         date: date, 
    //         tag: tag)
    //     for (package, (pin, consumers)):(Index, (Version, Set<Atom<Module>>)) in pins
    //     {
    //         assert(package != nationality)
    //         self[package].tree[pin].consumers[nationality, default: [:]][version] = consumers
    //     }
    //     return version
    // }
}

extension Packages 
{
    // mutating 
    // func spread(from index:Packages.Index, beliefs:Beliefs)
    // {
    //     let current:Version = self[index].versions.latest
    //     for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
    //     {
    //         self[diacritic.host.module.package].pollinate(local: diacritic.host, 
    //             from: .init(culture: diacritic.culture, version: current))
    //     }
    // }
}
