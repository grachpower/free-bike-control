import SwiftUI

#if os(macOS)
  import AppKit

  final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
      // Refresh the running Dock icon even when Launch Services cached an older build.
      if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
        let icon = NSImage(contentsOf: url)
      {
        NSApplication.shared.applicationIconImage = icon
      }
    }
  }
#endif

@main
struct freeBikeControlApp: App {
  #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
  #endif
  @StateObject private var session = RideSession()
  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(session)
    }
    #if os(macOS)
      .defaultSize(width: 1150, height: 920)
    #endif
  }
}
