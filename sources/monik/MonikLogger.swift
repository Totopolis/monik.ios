//
//  MonikLogger.swift
//  MonikiOS
//
//    Сергей Пестов on 10/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import Foundation
import RMQClient
import ProtocolBuffers

private extension Monik.Level {
    
    var severityType: MonikProto.SeverityType {
        switch self {
        case .trace : return .verbose
        case .info  : return .info
        case .warning: return .warning
        case .error : return .error
        case .fatal : return .fatal
        }
    }
}

private extension Monik.Source {
    
    var levelType: MonikProto.LevelType {
        switch self {
        case .application: return .application
        case .logic     : return .logic
        case .security  : return .security
        case .system    : return .system
        }
    }
}

open class MonikLogger: NSObject, Logger, Closable, InstanceIdentifiable {
    
    open func log(_ source: Monik.Source, _ level: Monik.Level, _ message: String) {
        
        let lg = MonikProto.Log.Builder()
        lg.body     = message
        lg.level    = source.levelType
        lg.severity = level.severityType
        lg.format   = MonikProto.FormatType.plain
        
        let eventBuilder = MonikProto.Event.Builder()
        eventBuilder.created = Int64(Date().timeIntervalSince1970 * 1000)
        eventBuilder.source = config?.source ?? "Application"
        eventBuilder.instance = instanceId
        
        eventBuilder.lg = try! lg.build()
        
        let event = try! eventBuilder.build()

        queue.async {
            self.publish(event.data())
        }
    }
    
    /// Publish data if connected or save if not
    ///
    /// - Parameter data: Data to be published
    private func publish(_ data: Data) {
    
        if #available (iOS 10.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        
        // If has connection try to enqueue
        if transport?.isConnected == true {
            let confirmNumber = transport!.publish(data)
    
            if let cfn = confirmNumber {
                events[cfn] = data
            }
        } else {
            // else save to publish later when connection restore
            items.append(data)
        }
    }
    
    open func close() {
        transport?.disconnect()
    }
    
    /// Check confirmation each 15 seconds
    @objc private func scheduleConfirm() {
        guard transport?.isConnected == true else {
            return
        }
        
        transport?.afterConfirmed { (ack, nack) in
            self.queue.async {
                self.removeConfirmed(ack: ack, nack: nack)
            }
        }
    }
    
    private func removeConfirmed(ack: Set<NSNumber>, nack: Set<NSNumber>) {
        
        if #available(iOS 10.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        
        guard !events.isEmpty else {
            return
        }
        
        guard ack.count != events.count else {
            events.removeAll(keepingCapacity: true)
            return
        }
        
        ack.forEach { (cfg) in
            events.removeValue(forKey: cfg.intValue)
        }
        
        guard transport?.isConnected == true,
            !events.isEmpty else
        {
            return
        }
        
        let reevents = events
        events.removeAll()
        
        let keys = reevents.keys.sorted(by:<)
        keys.forEach {
            if let data = reevents[$0] {
                publish(data)
            }
        }
    }
    
    private func sendOnReconnect() {
        
        if #available(iOS 10.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        
        guard !items.isEmpty else {
            return
        }
        
        let old = self.items
        self.items.removeAll()
        old.forEach {
            self.publish($0)
        }
    }
    
    private func initialize() {
        guard let config = config else {
            return
        }
        
        queue.async {
            self.transport = Transport(config: config) { [unowned self] (isConnected) in
                guard isConnected else {
                    return
                }
                
                self.queue.async {
                    self.sendOnReconnect()
                }
            }
        }
        
        timer = Timer.scheduledTimer(timeInterval: 15,
                                     target: self,
                                     selector: #selector(scheduleConfirm),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    private var transport: Transport?
    
    /// Serial Queue for syncronized publish and events manipulation.
    private let queue = DispatchQueue(label: "monik.publish")
    
    fileprivate var items: [Data] = []
    fileprivate var events: [Int: Data] = [:]
    fileprivate var timer: Timer?
    
    fileprivate var config: MonikLogger.Config? {
        didSet {
            if config != nil {
                initialize()
            }
        }
    }
    fileprivate var isSuspened = true
    
    open static let identifier = "monik"
    open var level: Monik.Level = .trace
    open var formatter: Formatter?
    open var instanceId: String = "0:0"
}

extension MonikLogger: Configurable {
    
    public func configure(with data: [AnyHashable : Any]) throws {
        
        try defaultConfigure(with: data)
        
        guard let monik = data["monik"] as? [AnyHashable: Any],
            let sync = monik["sync"] as? [AnyHashable: Any],
            let mq = sync["mq"] as? [AnyHashable: Any],
//            let meta = sync["meta"] as? [AnyHashable: Any] ,
            let config = MonikLogger.Config(
                with: mq,
                source:((sync["meta"] as? [AnyHashable: Any])?["source"]) as? String ?? "Application"),
            // параметры переотправки сообщения в очередь.
            let _ = monik["async"] as? [AnyHashable: Any] else
        {
            throw MonikError.configureError
        }
        
        self.config = config
    }
    
    /// Configure logger with configuration structure.
    ///
    /// - Parameter config: structure with configuration parameters.
    open func configure(with config: MonikLogger.Config) {
        self.config = config
    }
}
