import WebURL

extension Mongo
{
    public
    struct ConnectionStringParsingError:Error
    {
        public
        let url:String
    }
    public
    enum ConnectionStringError:Error
    {
        /// The scheme was not one of `mongodb` or `mongodb+srv`.
        case invalidScheme(String)
        case emptyHostsList
        case unsupportedFormParameter(String)
        case unsupportedAuthenticationMechanism(String)
    }
    @frozen public
    struct ConnectionString:Sendable
    {
        @frozen public
        enum Hosts:Sendable
        {
            case standard([Mongo.Host])
            case srv(Mongo.Host)
        }

        public
        var user:(name:String, password:String)?
        public 
        var hosts:Hosts
        public
        var defaultauthdb:Database?

        public
        var tls:Bool
        public
        var tlsCAFile:String?
        public
        var connectTimeout:Duration?
        public
        var socketTimeout:Duration?
        public
        var authSource:Database?
        public
        var authMechanism:ConnectionSettings.Authentication.Mechanism?
        public
        var appName:String?

        @inlinable public
        init(user:(name:String, password:String)? = nil,
            hosts:Hosts,
            defaultauthdb:Database? = nil,
            tls:Bool? = nil,
            tlsCAFile:String? = nil,
            connectTimeout:Duration? = nil,
            socketTimeout:Duration? = nil,
            authSource:Database? = nil,
            authMechanism:ConnectionSettings.Authentication.Mechanism? = nil,
            appName:String? = nil)
        {
            self.user = user
            self.hosts = hosts
            self.defaultauthdb = defaultauthdb
            switch self.hosts
            {
            case .srv:
                self.tls = tls ?? true
            case .standard:
                self.tls = tls ?? false
            }
            self.tlsCAFile = tlsCAFile
            self.connectTimeout = connectTimeout
            self.socketTimeout = socketTimeout
            self.authSource = authSource
            self.authMechanism = authMechanism
            self.appName = appName
        }
    }
}
extension Mongo.ConnectionString
{
    public
    init(parsing string:some StringProtocol) throws
    {
        if let url:WebURL = .init(string)
        {
            try self.init(url: url)
        }
        else
        {
            throw Mongo.ConnectionStringParsingError.init(url: .init(string))
        }
    }
    public
    init(url:WebURL) throws 
    {
        switch url.scheme
        {
        case "mongodb":
            self.tls = false
            if  let hosts:[Mongo.Host] = url.hostname?.split(separator: ",")
                        .map(Mongo.Host.mongodb(parsing:)),
                    !hosts.isEmpty
            {
                self.hosts = .standard(hosts)
            }
            else
            {
                throw Mongo.ConnectionStringError.emptyHostsList
            }
        
        case "mongodb+srv":
            self.tls = true
            if let name:String = url.hostname
            {
                self.hosts = .srv(.srv(name))
            }
            else
            {
                throw Mongo.ConnectionStringError.emptyHostsList
            }
        
        case let scheme:
            throw Mongo.ConnectionStringError.invalidScheme(scheme)
        }

        if  let name:String = url.username,
            let password:String = url.password
        {
            self.user = (name: name, password: password)
        }
        else
        {
            self.user = nil
        }

        self.defaultauthdb = url.path.isEmpty ? nil : .init(name: url.path)

        self.tlsCAFile = nil
        self.connectTimeout = nil
        self.socketTimeout = nil
        self.authSource = nil
        self.authMechanism = nil
        self.appName = nil

        for (key, value):(String, String) in url.formParams.allKeyValuePairs 
        {
            // note: value is case sensitive
            switch key.lowercased()
            {
            case "tls", "ssl":
                if let value:Bool = .init(value)
                {
                    self.tls = value
                }
            
            case "tlscafile":
                self.tlsCAFile = value
            
            case "connecttimeoutms":
                if let milliseconds:Int = .init(value)
                {
                    self.connectTimeout = .milliseconds(milliseconds)
                }
            case "sockettimeoutms":
                if let milliseconds:Int = .init(value)
                {
                    self.socketTimeout = .milliseconds(milliseconds)
                }
            
            case "authsource":
                self.authSource = .init(name: value)
            
            case "authmechanism":
                if  let mechanism:Mongo.ConnectionSettings.Authentication.Mechanism =
                        .init(rawValue: value)
                {
                    self.authMechanism = mechanism
                }
                else
                {
                    throw Mongo.ConnectionStringError.unsupportedAuthenticationMechanism(value)
                }
            
            case "appname":
                self.appName = value
            
            default:
                throw Mongo.ConnectionStringError.unsupportedFormParameter(key)
            }
        }
    }
}