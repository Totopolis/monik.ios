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
    
    public func log(_ source: Monik.Source, _ level: Monik.Level, _ message: String) {
        Swift.print(message)
    }

    open static let identifier = "console"
    open var level: Monik.Level = .trace
    open var formatter: Formatter?
}

