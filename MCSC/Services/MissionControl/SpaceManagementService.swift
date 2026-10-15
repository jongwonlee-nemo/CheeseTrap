import Cocoa

@MainActor
final class SpaceManagementService {
    private typealias CGSConnectionID = Int32

    @_silgen_name("CGSMainConnectionID")
    private static func CGSMainConnectionID() -> CGSConnectionID

    @_silgen_name("CGSCopyManagedDisplaySpaces")
    private static func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray?

    @_silgen_name("CGSCopySpacesForWindows")
    private static func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int32, _ windowIDs: CFArray) -> CFArray?

    func isWindowOnCurrentSpace(windowID: CGWindowID) -> Bool {
        let connection = Self.CGSMainConnectionID()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return true }
        let activeSpaces = Set(displays.compactMap { display in
            (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int
        })
        guard !activeSpaces.isEmpty,
              let spaces = Self.CGSCopySpacesForWindows(connection, 0x7, [NSNumber(value: windowID)] as CFArray) as? [Int],
              !spaces.isEmpty else { return true }
        return spaces.contains { activeSpaces.contains($0) }
    }
}
