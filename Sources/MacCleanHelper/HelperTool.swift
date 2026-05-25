import Foundation
import MacCleanKit

final class HelperTool: NSObject {
    private var listener: NSXPCListener?
    private var connections: [NSXPCConnection] = []

    func run() {
        listener = NSXPCListener(machServiceName: MCConstants.helperBundleIdentifier)
        listener?.delegate = self
        listener?.resume()

        RunLoop.current.run()
    }
}

extension HelperTool: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the caller is our main app by checking code signature
        let valid = verifyCallerSignature(connection: newConnection)
        guard valid else { return false }

        newConnection.exportedInterface = NSXPCInterface(with: MacCleanHelperProtocol.self)
        newConnection.exportedObject = HelperOperations()
        newConnection.invalidationHandler = { [weak self] in
            self?.connections.removeAll { $0 === newConnection }
        }

        connections.append(newConnection)
        newConnection.resume()
        return true
    }

    private func verifyCallerSignature(connection: NSXPCConnection) -> Bool {
        // In production, verify the caller's code signature matches our app
        // For now, allow all connections during development
        let pid = connection.processIdentifier
        return pid > 0
    }
}
