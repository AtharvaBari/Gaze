#if canImport(Sparkle)
import Sparkle

class SparkleManager {
    static let shared = SparkleManager()
    let updater: SUUpdater
    private init() {
        updater = SUUpdater()
        // Point to the GitHub Pages URL for the appcast
        updater.feedURL = URL(string: "https://AtharvaBari.github.io/Gaze-MacOS/appcast.xml")
        updater.automaticallyChecksForUpdates = true
    }
}
#else
class SparkleManager {
    static let shared = SparkleManager()
    let updater = DummyUpdater()
}
class DummyUpdater {
    func checkForUpdates(_ sender: Any? = nil) {}
    func checkForUpdates() {}
}
#endif
