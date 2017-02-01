//
//  Monik.swift
//  MonikiOS
//
//  Created by Сергей Пестов on 29/12/2016.
//  Copyright © 2016 SmartDriving. All rights reserved.
//

import Foundation

open class Monik: Closable {
    
    public enum Source {
        case system
        case application
        case logic
        case security
        
        var description: String {
            return String(describing: self)
        }
    }
    
    public enum Level {
        case trace, info, warning, error, fatal
        
        var description: String {
            return String(describing: self)
        }

        init?(from: String) {
            let all: [Level] = [.trace, .info, .warning, .error, .fatal]
            
            guard let found = all.filter({ $0.description == from }).first else {
                return nil
            }
            self = found
        }
    }
    
    open func securityFatal(_ message: String) {
        log(.security, .fatal, message)
    }
    
    open func systemTrace(_ message: String) {
        log(.system, .trace, message)
    }
    
    open func logicWarning(_ message: String) {
        log(.logic, .warning, message)
    }
    
    open func log(_ source: Source, _ level: Level, _ message: String) {
        queue.async {
            self.loggers.forEach {
                if level >= $0.level {
                    // format message with formatter or leave unchanged if nil formatter.
                    let msg = $0.formatter?.format(message) ?? message
                    // log message to queue.
                    $0.log(source, level, msg)
                }
            }
        }
    }
    
    open func close() {
        loggers.forEach { ($0 as? Closable)?.close() }
    }
    
    open var loggers: [Logger] = []
    
    fileprivate let queue = DispatchQueue(label: "monik.log")
    
    open static var `default`: Monik = {
        let m = Monik()
        m.loggers = [ ConsoleLogger() ]
        return m
    }()
}

extension Monik {
    
    open func configure(with data: [AnyHashable : Any], factory: Factory.Type) throws {
        guard let loggers = data["loggers"] as? [[AnyHashable: Any]] else {
            throw MonikError.configureError
        }
        
        self.loggers = loggers.flatMap {
            guard let channel = $0["channel"] as? String,
                let logger = factory.instantiate(channel) else
            {
                    return nil
            }
            
            if let enabled = $0["enabled"] as? Bool,
                enabled == false
            {
                return nil
            }
            
            try? (logger as? Configurable)?.configure(with: $0)
            
            return logger
        }
    }
    
    open func configure(with url: URL) {
        
        queue.async {
            guard let data = try? Data(contentsOf: url),
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any],
                let configuration = json else
            {
                return
            }
            
            try? self.configure(with: configuration, factory: Factory.self)
        }
    }
}


extension Monik.Level: Comparable {}

public func ==(lhs: Monik.Level, rhs: Monik.Level) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

public func <(lhs: Monik.Level, rhs: Monik.Level) -> Bool {
    return lhs.hashValue < rhs.hashValue
}
