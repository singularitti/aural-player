/*
    View controller for the "Track Info" popover
*/

import Cocoa

class PopoverViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    private var info: [(key: String, value: String)] = [(key: String, value: String)]()
    @IBOutlet weak var trackInfoView: NSTableView!
    
    private let player: PlaybackDelegateProtocol = ObjectGraph.getPlaybackDelegate()
    
    override func loadView() {
        
        super.loadView()
        
        // Store reference to the table view for later use
        trackInfoView.reloadData()
        trackInfoView.scrollRowToVisible(0)
    }
    
    // Called each time the popover is shown ... refreshes the data in the table view depending on which track is currently playing
    func refresh() {
        
        if (trackInfoView != nil) {
            trackInfoView.reloadData()
            trackInfoView.scrollRowToVisible(0)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        let _track = player.getPlayingTrack()?.track
        if (_track == nil) {
            return 0
        }
        
        let track = _track!
        
        info.removeAll()
        
        info.append((key: "Filename", value: track.file.path))
        info.append((key: "Size", value: track.size!.toString()))
        info.append((key: "Format", value: track.format!))
        info.append((key: "Duration", value: Utils.formatDuration(track.duration!)))
        
        if (track.metadata != nil) {
            
            if (track.metadata!.artist != nil) {
                info.append((key: "Artist", value: track.metadata!.artist!))
            }
            
            if (track.metadata!.title != nil) {
                info.append((key: "Title", value: track.metadata!.title!))
            }
        }
        
        for (key, value) in track.extendedMetadata {
            // Some tracks have a "Format" metadata entry ... ignore it
            if (key.lowercased() != "format") {
                info.append((key: Utils.splitCamelCaseWord(key, true), value: value))
            }
        }
        
        info.append((key: "Bit Rate", value: String(format: "%d kbps", track.bitRate!)))
        info.append((key: "Sample Rate", value: String(format: "%@ Hz", Utils.readableLongInteger(Int64(track.sampleRate!)))))
        info.append((key: "Channels", value: String(track.numChannels!)))
        info.append((key: "Frames", value: Utils.readableLongInteger(track.frames!)))
        
        return info.count
    }
    
    // Each track info view row contains one key-value pair
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        
        let _track = player.getPlayingTrack()?.track
        if (_track == nil) {
            return nil
        }
        
        let track = _track!
        
        let view = TrackInfoView()
        view.track = track
        view.trackInfoView = trackInfoView!
        
        view.key = info[row].key
        view.value = info[row].value
        
        return view
    }
    
    // Adjust row height based on if the text wraps over to the next line
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        
        // Check if the text for the current row will exceed column width (value column)
        let myString: NSString = info[row].value as NSString
        let size: CGSize = myString.size(withAttributes: [NSFontAttributeName: UIConstants.popoverValueFont as AnyObject])
        
        if (size.width > UIConstants.trackInfoValueColumnWidth) {
            
            let rows = Int(size.width / UIConstants.trackInfoValueColumnWidth) + 1
            // This means the text has wrapped over to the second line
            // So, increase the row height
            return CGFloat(rows) * UIConstants.trackInfoValueRowHeight * UIConstants.trackInfoLongValueRowHeightMultiplier
        } else {
            // No wrap, one row height is enough
            return UIConstants.trackInfoValueRowHeight
        }
    }
    
    // Completely disable row selection
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}
