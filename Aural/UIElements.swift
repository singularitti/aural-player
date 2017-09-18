import Cocoa

/*
    Container for definitions of reusable UI components
*/
class UIElements {
    
    // TODO: Make these lazy vars to reduce memory footprint ???
    
    // Used to add tracks/playlists
    static let openDialog: NSOpenPanel = UIElements.createOpenPanel()
    
    // Used to save current playlist to a file
    static let savePlaylistDialog: NSSavePanel = UIElements.createSavePanel()
    
    // Used to save a recording to a file
    static let saveRecordingDialog: NSSavePanel = UIElements.createSaveRecordingPanel()
    
    // Used to prompt the user, when exiting the app, that a recording is ongoing, and give the user options to save/discard that recording
    static let saveRecordingAlert: NSAlert = UIElements.createSaveRecordingAlert()
    
    // Used to inform the user that a certain track cannot be played back
    static let trackNotPlayedAlert: NSAlert = UIElements.createTrackNotPlayedAlert()
    
    // Used to warn the user that certain files were not added to the playlist
    static let tracksNotAddedAlert: NSAlert = UIElements.createTracksNotAddedAlert()
    
    private static func createOpenPanel() -> NSOpenPanel {
        
        let dialog = NSOpenPanel()
        
        dialog.title                   = "Choose media (.mp3/.m4a/.aac/.aif/.wav), playlists (.m3u/.m3u8), or directories";
        
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = true;
        
        dialog.canChooseDirectories    = true;
        
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = true;
        dialog.allowedFileTypes        = AppConstants.supportedFileTypes_open
        
        dialog.resolvesAliases = true;
        
        dialog.directoryURL = AppConstants.musicDirURL
        
        return dialog
    }
    
    private static func createSavePanel() -> NSSavePanel {
        
        let dialog = NSSavePanel()
        
        dialog.title                   = "Save current playlist as a (.m3u) file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = true
        
        dialog.canCreateDirectories    = true
        dialog.allowedFileTypes        = AppConstants.supportedFileTypes_save
        
        dialog.directoryURL = AppConstants.musicDirURL
        
        return dialog
    }
    
    private static func createSaveRecordingPanel() -> NSSavePanel {
        
        let dialog = NSSavePanel()
        
        dialog.title                   = "Save recording as a (.aac) file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        
        dialog.canCreateDirectories    = true
        dialog.allowedFileTypes        = [RecordingFormat.aac.fileExtension]
        
        dialog.directoryURL = AppConstants.musicDirURL
        
        return dialog
    }
    
    private static func createSaveRecordingAlert() -> NSAlert {
        
        let alert = NSAlert()
        
        alert.window.title = "Save/discard ongoing recording"
        
        alert.messageText = "You have an ongoing recording. Would you like to save it before exiting the app ?"
        alert.alertStyle = .warning
        alert.icon = UIConstants.imgWarning
        
        alert.addButton(withTitle: "Save recording and exit")
        alert.addButton(withTitle: "Discard recording and exit")
        alert.addButton(withTitle: "Don't exit")
        
        return alert
    }
    
    private static func createTrackNotPlayedAlert() -> NSAlert {
        
        let alert = NSAlert()
        
        alert.window.title = "Track not playable"
        
        alert.alertStyle = .warning
        alert.icon = UIConstants.imgError

        alert.addButton(withTitle: "Remove track from playlist")
        
        return alert
    }
    
    static func trackNotPlayedAlertWithError(_ error: InvalidTrackError) -> NSAlert {
        
        let alert = trackNotPlayedAlert
        
        alert.messageText = String(format: "The track '%@' cannot be played back !", error.file.lastPathComponent)
        alert.informativeText = error.message
        
        return alert
    }
    
    private static func createTracksNotAddedAlert() -> NSAlert {
        
        let alert = NSAlert()
        
        alert.window.title = "File(s) not added"
        
        let infoText: String = "- File(s) point to missing/broken paths.\n- Playlist file(s) point to audio file(s) with missing/broken paths.\n- File(s) are corrupted/damaged."
        
        alert.informativeText = infoText
        
        alert.alertStyle = .warning
        alert.icon = UIConstants.imgWarning
        
        let rect: NSRect = NSRect(x: alert.window.frame.origin.x, y: alert.window.frame.origin.y, width: alert.window.frame.width, height: 150)
        alert.window.setFrame(rect, display: true)
        
        alert.addButton(withTitle: "Ok")
        
        return alert
    }
    
    static func tracksNotAddedAlertWithErrors(_ errors: [InvalidTrackError]) -> NSAlert {
        
        let alert = tracksNotAddedAlert
        
        let numErrors = errors.count
        
        alert.messageText = String(format: "%d of your chosen files were not added to the playlist. Possible reasons are listed below.", numErrors)
        
        return alert
    }
}

// Enumeration of all possible responses in the save/discard ongoing recording alert (possibly) displayed when exiting the app
enum RecordingAlertResponse: Int {
    
    case saveAndExit = 1000
    case discardAndExit = 1001
    case dontExit = 1002
}
