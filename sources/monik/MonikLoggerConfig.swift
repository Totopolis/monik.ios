//
//  MonikLoggerConfig.swift
//  monik
//
//  Created by Sergey Pestov on 20/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation

extension MonikLogger {
    /// Structure for configurating monik logger.
    public struct Config {
        public var host        = "localhost"
        public var port        = 5672
        public var username    = "test"
        public var password    = "test"
        public var exchange    = ""
        public var durable     = true
        public var reconnectTimeout = 5
        public var useSsl      = true
        public var source      = ""
        /// Connection string for rabbitMQ client.
        public var uri         = ""
    }
}
extension MonikLogger.Config {
    
    public init(uri: String) {
        self.uri = uri
    }
    
    public init?(with data: [AnyHashable : Any], source: String)  {
        self.durable = data["durable"] as? Bool ?? true
        self.exchange = data["exchange"] as? String ?? ""
        self.source = source
        
        if let uri = data["uri"] as? String {
            self.uri = uri
            return
        }
        
        if let host = data["host"] as? String,
            let port = data["port"] as? Int,
            let user = data["user"] as? String,
            let password = data["password"] as? String
        {
            self.host = host
            self.port = port
            self.username = user
            self.password = password
            self.useSsl = data["useSsl"] as? Bool ?? false
            let scheme = useSsl ? "amqps" : "amqp"
            self.uri = "\(scheme)://\(username):\(password)@\(host):\(port)"
        } else {
            return nil
        }
    }
}
