//
//  CommonProtocols.swift
//  MonikiOS
//
//  Created by Sergey Pestov on 10/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation

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
            let level = Monik.level(from: rawLevel)
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

