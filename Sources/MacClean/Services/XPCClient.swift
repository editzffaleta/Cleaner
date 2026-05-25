import Foundation
import MacCleanKit

public actor XPCClient {
    private var connection: NSXPCConnection?

    public static let shared = XPCClient()

    private init() {}

    public func connect() -> NSXPCConnection {
        if let existing = connection, !existing.isEqual(nil) {
            return existing
        }

        let conn = NSXPCConnection(machServiceName: MCConstants.helperBundleIdentifier, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: MacCleanHelperProtocol.self)
        conn.invalidationHandler = {
            // Connection invalidated — next call to connect() will create a new one
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func handleDisconnect() {
        connection = nil
    }

    public func removeFiles(atPaths paths: [String]) async throws {
        let conn = connect()
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as! MacCleanHelperProtocol

            proxy.removeFiles(atPaths: paths) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func runMaintenanceScript(_ script: String) async throws -> String {
        let conn = connect()
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as! MacCleanHelperProtocol

            proxy.runMaintenanceScript(script) { output, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: output)
                }
            }
        }
    }

    public func flushDNSCache() async throws {
        let conn = connect()
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as! MacCleanHelperProtocol

            proxy.flushDNSCache { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func reindexSpotlight() async throws {
        let conn = connect()
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as! MacCleanHelperProtocol

            proxy.reindexSpotlight { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
