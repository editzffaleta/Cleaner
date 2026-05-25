import Foundation

@objc public protocol MacCleanHelperProtocol {
    func removeFiles(atPaths paths: [String], reply: @escaping (NSError?) -> Void)
    func runMaintenanceScript(_ script: String, reply: @escaping (String, NSError?) -> Void)
    func flushDNSCache(reply: @escaping (NSError?) -> Void)
    func repairPermissions(reply: @escaping (String, NSError?) -> Void)
    func reindexSpotlight(reply: @escaping (NSError?) -> Void)
    func thinTimeMachineSnapshots(reply: @escaping (String, NSError?) -> Void)
    func freeUpPurgeableSpace(reply: @escaping (String, NSError?) -> Void)
}
