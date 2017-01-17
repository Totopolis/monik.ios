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

open class MonicLogger: Logger, Closable, InstanceIdentifiable {
    
    /// Structure for configurating monik logger.
    public struct Config {
        var host        = "localhost"
        var port        = 5672
        var username    = "test"
        var password    = "test"
        var exchange    = "monik.queue"
        var durable     = true
        
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
        
        let confirmNumber = exchange?.publish(event.data())
        
        print("Confirm: \(confirmNumber ?? 0)")
    }
    
    open func close() {
        conn?.close()
    }
    
    private func initialize() {
        guard let config = config else {
            return
        }
        
        print("Connect with uri: \(config.uri)")
        
        conn = RMQConnection(uri: config.uri, delegate: delegate)
        conn?.start()
        
        let ch = conn?.createChannel()
        
        ch?.confirmSelect()
        
        let opt: RMQExchangeDeclareOptions = config.durable ? [.durable] : []
        
        exchange = ch?.fanout(config.exchange, options: opt)
    }
    
    private var conn: RMQConnection?
    private var exchange: RMQExchange?
    private let delegate = RMQConnectionDelegateLogger()
    
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
}

extension MonicLogger: Configurable {
    
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
}

extension MonicLogger.Config {
    
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

open class MonikRMQConnectionDelegate: NSObject, RMQConnectionDelegate {
    
    /// @brief Called when a socket cannot be opened, or when AMQP handshaking times out for some reason.
    public func connection(_ connection: RMQConnection!, failedToConnectWithError error: Error!) {
        print("Failed to connect with error: \(error)")
    }
    
    /// @brief Called when a connection disconnects for any reason
    public func connection(_ connection: RMQConnection!, disconnectedWithError error: Error!) {
        print("Disconnected with error: \(error)")
    }
    
    /// @brief Called before the configured <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> sleep.
    public func willStartRecovery(with connection: RMQConnection!) {
        print("Will start recovery with \(connection)")
    }
    
    /// @brief Called after the configured <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> sleep.
    public func startingRecovery(with connection: RMQConnection!) {
        print("Starting recovery with \(connection)")
    }
    
    /*!
     * @brief Called when <a href="http://www.rabbitmq.com/api-guide.html#recovery">automatic connection recovery</a> has succeeded.
     * @param RMQConnection the connection instance that was recovered.
     */
    public func recoveredConnection(_ connection: RMQConnection!) {
        print("Recovered connection \(connection)")
    }
    
    /// @brief Called with any channel-level AMQP exception.
    public func channel(_ channel: RMQChannel!, error: Error!)  {
        print("Channgel exception \(error)")
    }
    
}
