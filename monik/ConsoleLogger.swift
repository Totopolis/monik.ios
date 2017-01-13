//
//  ConsoleLogger.swift
//  MonikiOS
//
//  Created by Sergey Pestov on 10/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation

/// Class for logging to console.
open class ConsoleLogger: Logger, Configurable {
    
    public func log(_ source: Monik.source, _ level: Monik.level, _ message: String) {
        Swift.print(message)
    }

    public static let identifier = "console"
    public var level: Monik.level = .trace
}

