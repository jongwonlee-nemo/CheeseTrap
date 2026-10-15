import Cocoa

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    // NSApplication holds its delegate weakly; keep it alive for the entire event loop.
    withExtendedLifetime(delegate) {
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
