//
//  InstanceIdFormatter.swift
//  monikDemo
//
//  Created by Sergey Pestov on 13/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation
import monik

struct InstanceIdFormatter: monik.Formatter {
    
    func format(_ message: String) -> String {
        return "[\(instanceId)] \(message)"
    }
    
    var instanceId: String
}

