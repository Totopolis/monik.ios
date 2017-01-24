//
//  MonikLoggerTransport.swift
//  Pods
//
//  Created by Sergey Pestov on 20/01/2017.
//
//

import Foundation
import RMQClient

extension MonikLogger {
    
    open class Transport: NSObject {
        
        init(config: Config, connectedBlock: ((Bool) -> Void)?) {
            self.config = config
            self.connectedBlock = connectedBlock
            
            super.init()
            
            print("Connect with uri: \(config.uri)")
            
            conn = RMQConnection(uri: config.uri,
                                 delegate: self,
                                 recoverAfter: NSNumber(value: config.reconnectTimeout))
            
            connect()
        }
        
        @objc private func reconnectIfNeeded() {
            guard !isConnected, !isConnecting else {
                return
            }
            
            isConnecting = true
            reconnect()
        }
        
        deinit {
            disconnect()
        }
        
        private func connect() {
            
            conn.start() {
                self.isConnected = true
                print("!!! [CONNECTED] !!!")
            }
            
            let ch = conn.createChannel()
            
            ch.confirmSelect()
            
            channel = ch
            
            let opt: RMQExchangeDeclareOptions = config.durable ? [.durable] : []
            
            exchange = ch.fanout(config.exchange, options: opt)
        }
        
        /// Close and forget.
        open func disconnect() {
            conn?.close()
            conn = nil
        }
        
        open func reconnect() {
            self.nackCount = 0
            
            disconnect()
            
            conn = RMQConnection(uri: config.uri, delegate: self, recoverAfter: NSNumber(value: config.reconnectTimeout))
            connect()
        }
        
        open func afterConfirmed(_ handler: @escaping (Set<NSNumber>, Set<NSNumber>) -> Void) {
            
            channel.afterConfirmed(NSNumber(value: 0)) { (ack, nack) in
                handler(ack, nack)
                
                guard self.isConnected else {
                    return
                }
                
                if nack.isEmpty {
                    self.nackCount = 0
                } else {
                    self.nackCount += 1
                    if self.nackCount == 3 {
                        // Reconnect if cannot send messages 3 times when connected.
                        self.reconnect()
                    }
                }
            }
        }
        
        open func publish(_ data: Data) -> Int? {
            return exchange.publish(data, routingKey: "", persistent: true )?.intValue
        }
        
        private let config: Config
        
        private var conn: RMQConnection!
        private var exchange: RMQExchange!
        private var channel: RMQChannel!
        
        fileprivate (set) var isConnected = false {
            didSet {
                isConnecting = false
                connectedBlock?(isConnected)
            }
        }
        fileprivate (set) var isConnecting = false
        
        private var nackCount = 0
        
        private var timer: Timer?
        
        var connectedBlock: ((Bool) -> Void)?
    }
}

//open class MonikRMQConnectionDelegate: NSObject, RMQConnectionDelegate {
extension MonikLogger.Transport: RMQConnectionDelegate {
    
    /// @brief Called when a socket cannot be opened, or when AMQP handshaking times out for some reason.
    public func connection(_ connection: RMQConnection!, failedToConnectWithError error: Error!) {
        print("[DISCONNECTED] Failed to connect with error: \(error)")
        isConnected = false
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
