import Cocoa

class PlaybackPreferencesViewController: NSViewController, PreferencesViewProtocol {
    
    @IBOutlet weak var tabView: AuralTabView!
    
    @IBOutlet var generalPrefsView: GeneralPlaybackPreferencesViewController!
    
    override var nibName: String? {return "PlaybackPreferences"}
    
    var preferencesView: NSView {
        return self.view
    }
    
    func resetFields(_ preferences: Preferences) {
        
        generalPrefsView.resetFields(preferences)
        
        tabView.selectTabViewItem(at: 0)
    }
    
    func save(_ preferences: Preferences) throws {
        
        try generalPrefsView.save(preferences)
    }
}
