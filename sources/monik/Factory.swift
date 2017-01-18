//
//  Factory.swift
//  MonikiOS
//
//  Created by Sergey Pestov on 13/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation

/// Create logger instance with identifier.
open class Factory {
    
    /// Create Logger instance using identifier. If identifier is unknown then
    /// method returns `nil`.
    ///
    /// - Parameter identifier: unique identifier for logger.
    /// - Returns: logger instance or `nil` if identifier is unknown.
    static func instantiate(_ identifier: String) -> Logger? {
        
        switch identifier {
        case ConsoleLogger.identifier:
            return ConsoleLogger()
        case MonikLogger.identifier:
            return MonikLogger()
        default:
            return nil
        }
    }
}
