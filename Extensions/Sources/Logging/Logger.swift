//
//  Logger.swift
//  Extensions
//
//  Created by sudo.park on 2023/09/19.
//

import Foundation
import Pulse


public final class Logger: @unchecked Sendable {
    
    fileprivate init() { }
    
    public enum LogLevel {
        case trace
        case debug
        case info
        case notice
        case warning
        case error
        case critical
        
        fileprivate var asPulseLoggerLevel: LoggerStore.Level {
            switch self {
            case .trace: return .trace
            case .debug: return .debug
            case .info: return .info
            case .notice: return .notice
            case .warning: return .warning
            case .error: return .error
            case .critical: return .critical
            }
        }
    }
    
    public enum Label: String {
        case `default`
        case sql = "SQL"
    }
    
    public func prepare() {
        URLSessionProxyDelegate.enableAutomaticRegistration()
    }
}

extension Logger {
    
    public func log(
        _ label: Label = .default,
        level: LogLevel,
        _ message: String,
        with metadata: [String: Any]? = nil
    ) {
        let metadata = metadata?.mapValues { anyValue -> LoggerStore.MetadataValue in
            switch anyValue {
            case let string as String:
                return .string(string)
            case let stringConvertable as any CustomStringConvertible:
                return .stringConvertible(stringConvertable)
            default:
                return .string("\(anyValue)")
            }
        }
        LoggerStore.shared.storeMessage(
            label: label.rawValue,
            level: level.asPulseLoggerLevel,
            message: message,
            metadata: metadata
        )
    }
}

public let logger = Logger()
