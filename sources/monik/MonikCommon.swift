//
//  CommonProtocols.swift
//  MonikiOS
//
//  Created by Sergey Pestov on 10/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation

/// Protocol for logger.
public protocol Logger: class {
    
    /// Identifier of logger instance. Used in factory to instantiate new logger.
    static var identifier: String { get }
    
    /// Current logging level. Can be changed at any time.
    var level: Monik.Level { get set }
    
    /// Formatter which applied to each logged message
    var formatter: Formatter? { get set }
    
    /// Loggin method.
    ///
    /// - Parameters:
    ///   - source: Log source of current application.
    ///   - level: Severity level of current logging message. Skipped if message
    ///             level less then current logger level.
    ///   - message: Log message
    func log(_ source: Monik.Source, _ level: Monik.Level, _ message: String)
}

/// Protocol for formatting messages to the log
public protocol Formatter {
    func format(_ message: String) -> String
}

/// Protocol for setting unique identifier for instance of logger
public protocol InstanceIdentifiable: class {
    var instanceId: String { get set }
}

/// Enum defining possible errors
///
/// - configureError: Wrong configuration file or parameters
public enum MonikError: Error {
    case configureError
}

/// Protocol for configurable items
public protocol Configurable {
    /// Configure item
    ///
    /// - Parameter data: Dictionary with configuration items
    /// - Throws: confgirureError if necessary fields missed
    func configure(with data: [AnyHashable: Any]) throws
}

// MARK: - Logger
extension Configurable where Self: Logger {
    
    /// Default implementation for Configurable logger
    ///
    /// - Parameter data: Dictionary with configuration items
    /// - Throws: confgirureError if necessary fields missed
    public func configure(with data: [AnyHashable: Any]) throws {
        try defaultConfigure(with: data)
    }
    
    /// Configure properties default for all loggers
    ///
    /// - Parameter data: Dictionary with configuration items
    /// - Throws: confgirureError if necessary fields missed
    public func defaultConfigure(with data: [AnyHashable: Any]) throws {
        if let rawLevel = data["level"] as? String,
            let level = Monik.Level(from: rawLevel)
        {
            self.level = level
        } else {
            throw MonikError.configureError
        }
    }
}

/// Protocol for items which should be explicitly closed
public protocol Closable: class {
    /// Close logger
    func close()
}

