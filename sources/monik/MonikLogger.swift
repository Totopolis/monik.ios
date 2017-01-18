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

open class MonikLogger: NSObject, Logger, Closable, InstanceIdentifiable {
    
    /// Structure for configurating monik logger.
    public struct Config {
        var host        = "localhost"
        var port        = 5672
        var username    = "test"
        var password    = "test"
        var exchange    = "monik.queue"
        var durable     = true
        var reconnectTimeout = 3
        
        /// Connection string for rabbitMQ client.
        var uri: String {
            return "amqp://\(username):\(password)@\(host):\(port)"
        }
    }
    
    open func log(_ source: Monik.source, _ level: Monik.level, _ message: String) {
        
        let lg = Tutorial.Log.Builder()
        lg.body     = message
        lg.level    = Tutorial.LevelType.application
        lg.severity = Tutorial.SeverityType.verbose
        lg.format   = Tutorial.FormatType.plain
        
        let eventBuilder = Tutorial.Event.Builder()
        eventBuilder.created = Int64(Date().timeIntervalSinceNow * 1000)
        eventBuilder.source = source.description
        eventBuilder.instance = instanceId
        
        eventBuilder.lg = try! lg.build()
        
        let event = try! eventBuilder.build()

        queue.sync {
            publish(event.data())
        }
    }
    
    private func publish(_ data: Data) {
        
        let confirmNumber = exchange.publish(data, routingKey: "", persistent: true )
        
        if let cfn = confirmNumber {
            events[cfn] = data
        }
        
        print("Confirm: \(confirmNumber ?? 0)")
    }
    
    open func close() {
        conn.close()
    }
    
    @objc private func scheduleConfirm() {
        channel.afterConfirmed(0) { [weak self] (ack, nack) in
            self?.queue.sync {
                print("nack: \(nack)")
                self?.removeConfirmed(ack: ack, nack: nack)
            }
        }
    }
    
    private func removeConfirmed(ack: Set<NSNumber>, nack: Set<NSNumber>) {
        print("Before \(events.count)")
        
        guard !events.isEmpty else {
            return
        }
        
        guard ack.count != events.count else {
            events.removeAll(keepingCapacity: true)
            return
        }
        
        ack.forEach { (cfg) in
            events.removeValue(forKey: cfg)
        }
        print("After \(events.count)")
        
        if isConnected && !events.isEmpty {
            let reevents = events
            events.removeAll(keepingCapacity: true)
            
            reevents.forEach {
                publish($0.value)
            }
        }
    }
    
    private func initialize() {
        guard let config = config else {
            return
        }
        
        print("Connect with uri: \(config.uri)")
        
        conn = RMQConnection(uri: config.uri, delegate: self)//, delegate: delegate, recoverAfter: NSNumber(value: config.reconnectTimeout))
        conn.start()
        
        let ch = conn.createChannel()
        
        ch.confirmSelect()
        
        channel = ch
  
        timer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(scheduleConfirm), userInfo: nil, repeats: true)
        
        let opt: RMQExchangeDeclareOptions = config.durable ? [.durable] : []
        
        exchange = ch.fanout(config.exchange, options: opt)
    }
    
    private func republish() {
        
    }
    
    private var conn: RMQConnection!
    private var exchange: RMQExchange!
    private var channel: RMQChannel!
//    private let delegate = MonikRMQConnectionDelegate()
    
    /// Queue for syncronized publish and events manipulation.
    private let queue = DispatchQueue(label: "monik.publish")
    
    fileprivate var events: [NSNumber: Data] = [:]
    fileprivate var timer: Timer?
    
    fileprivate var config: Config? {
        didSet {
            if config != nil {
                initialize()
            }
        }
    }
    
    open static let identifier = "monik"
    open var level: Monik.level = .trace
    open var formatter: Formatter?
    open var instanceId: String = "[0:0]"
    
    fileprivate (set) var isConnected = false {
        didSet {
            if isConnected {
                republish()
            }
        }
    }
}

extension MonikLogger: Configurable {
    
    public func configure(with data: [AnyHashable : Any]) throws {
        
        try defaultConfigure(with: data)
        
        guard let monik = data["monik"] as? [AnyHashable: Any],
            let sync = monik["sync"] as? [AnyHashable: Any],
            let mq = sync["mq"] as? [AnyHashable: Any],
            let config = Config(with: mq),
//            let meta = sync["meta"] as? [AnyHashable: Any],
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
    open func configure(with config: Config) {
        self.config = config
    }
}

extension MonikLogger.Config {
    
    init?(with data: [AnyHashable : Any])  {
        if let host = data["host"] as? String,
            let port = data["port"] as? Int,
            let user = data["user"] as? String,
            let password = data["password"] as? String,
            let exchange = data["exchange"] as? String,
            let durable = data["durable"] as? Bool
        {
            self.host = host
            self.port = port
            self.username = user
            self.password = password
            self.exchange = exchange
            self.durable = durable
        } else {
            return nil
        }
    }
}

// MARK: -

//open class MonikRMQConnectionDelegate: NSObject, RMQConnectionDelegate {
extension MonikLogger: RMQConnectionDelegate {
    
    /// @brief Called when a socket cannot be opened, or when AMQP handshaking times out for some reason.
    public func connection(_ connection: RMQConnection!, failedToConnectWithError error: Error!) {
        print("[DISCONNECTED] Failed to connect with error: \(error)")
    }
    
    /// @brief Called when a connection disconnects for any reason
    public func connection(_ connection: RMQConnection!, disconnectedWithError error: Error!) {
        print("[DISCONNECTED] Disconnected with error: \(error)")
        
        isConnected = false
    }
    
    /// @brief Called before the configured <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> sleep.
    public func willStartRecovery(with connection: RMQConnection!) {
        print("[DISCONNECTED] Will start recovery with \(connection)")
    }
    
    /// @brief Called after the configured <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> sleep.
    public func startingRecovery(with connection: RMQConnection!) {
        print("[DISCONNECTED] Starting recovery with \(connection)")
    }
    
    /*!
     * @brief Called when <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> has succeeded.
     * @param RMQConnection the connection instance that was recovered.
     */
    public func recoveredConnection(_ connection: RMQConnection!) {
        print("[CONNECTED] Recovered connection \(connection)")
        isConnected = true
    }
    
    /// @brief Called with any channel-level AMQP exception.
    public func channel(_ channel: RMQChannel!, error: Error!)  {
        print("[???] Channel exception \(error)")
    }
    
    
}
