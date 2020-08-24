import Cocoa

/*
 View controller for the flat ("Tracks") playlist view
 */
class LibraryTracksViewController: AuralViewController {
    
    @IBOutlet weak var libraryView: NSTableView!
    @IBOutlet weak var header: NSTableHeaderView!
    @IBOutlet weak var scroller: NSScroller!
    
    @IBOutlet weak var lblTracksSummary: NSTextField!
    @IBOutlet weak var lblDurationSummary: NSTextField!
    
    private let library: LibraryDelegateProtocol = ObjectGraph.libraryDelegate
    private let playQueue: PlayQueueDelegateProtocol = ObjectGraph.playQueueDelegate
    private let playbackInfo: PlaybackInfoDelegateProtocol = ObjectGraph.playbackInfoDelegate
    
    override var nibName: String? {return "LibraryTracks"}
    
    private var selectedRows: IndexSet {libraryView.selectedRowIndexes}
    
    private var selectedRowsArr: [Int] {libraryView.selectedRowIndexes.toArray()}
    
    private var selectedRowCount: Int {libraryView.numberOfSelectedRows}
    
    private var atLeastOneSelectedRow: Bool {libraryView.numberOfSelectedRows > 0}
    
    private var rowCount: Int {libraryView.numberOfRows}
    
    private var atLeastOneRow: Bool {libraryView.numberOfRows > 0}
    
    private var lastRow: Int {rowCount - 1}
    
    override func initializeUI() {
        
        changeTextSize(PlaylistViewState.textSize)
        doApplyColorScheme(ColorSchemes.systemScheme, false)
        
        updateSummary()
        libraryView.enableDragDrop_files()
    }
    
    override func initializeSubscriptions() {
        
        Messenger.subscribeAsync(self, .player_trackTransitioned, self.trackTransitioned(_:), queue: .main)
        Messenger.subscribeAsync(self, .library_trackAdded, self.trackAdded(_:), queue: .main)
        Messenger.subscribeAsync(self, .library_tracksRemoved, self.tracksRemoved(_:), queue: .main)
        
        Messenger.subscribe(self, .library_removeTracks, self.removeSelectedTracks)
        Messenger.subscribe(self, .library_refresh, {(selector: PlaylistViewSelector) in self.refresh()})
        
        Messenger.subscribe(self, .library_playNow, self.playNow)
        Messenger.subscribe(self, .library_playNext, self.playNext)
        Messenger.subscribe(self, .library_playLater, self.playLater)
        
        Messenger.subscribe(self, .library_clearSelection, {(selector: PlaylistViewSelector) in self.clearSelection()})
        Messenger.subscribe(self, .library_invertSelection, {(selector: PlaylistViewSelector) in self.invertSelection()})
        Messenger.subscribe(self, .library_cropSelection, {(selector: PlaylistViewSelector) in self.cropSelection()})
        
        Messenger.subscribe(self, .library_scrollToTop, {(selector: PlaylistViewSelector) in self.scrollToTop()})
        Messenger.subscribe(self, .library_scrollToBottom, {(selector: PlaylistViewSelector) in self.scrollToBottom()})
        Messenger.subscribe(self, .library_pageUp, {(selector: PlaylistViewSelector) in self.pageUp()})
        Messenger.subscribe(self, .library_pageDown, {(selector: PlaylistViewSelector) in self.pageDown()})
        
        // MARK: Appearance
        
        Messenger.subscribe(self, .playlist_changeTextSize, self.changeTextSize(_:))
        
        Messenger.subscribe(self, .applyColorScheme, self.applyColorScheme(_:))
        Messenger.subscribe(self, .changeBackgroundColor, self.changeBackgroundColor(_:))
        
        Messenger.subscribe(self, .playlist_changeTrackNameTextColor, self.changeTrackNameTextColor(_:))
        Messenger.subscribe(self, .playlist_changeIndexDurationTextColor, self.changeIndexDurationTextColor(_:))
        
        Messenger.subscribe(self, .playlist_changeTrackNameSelectedTextColor, self.changeTrackNameSelectedTextColor(_:))
        Messenger.subscribe(self, .playlist_changeIndexDurationSelectedTextColor, self.changeIndexDurationSelectedTextColor(_:))
        
        Messenger.subscribe(self, .playlist_changePlayingTrackIconColor, self.changePlayingTrackIconColor(_:))
        Messenger.subscribe(self, .playlist_changeSelectionBoxColor, self.changeSelectionBoxColor(_:))
        
        Messenger.subscribe(self, .playlist_changeSummaryInfoColor, self.changeSummaryInfoColor(_:))
    }
    
    func trackAdded(_ notification: LibraryTrackAddedNotification) {
        
        libraryView.noteNumberOfRowsChanged()
        updateSummary()
    }
    
    private func trackTransitioned(_ notification: TrackTransitionNotification) {
        
        let refreshIndexes: IndexSet = IndexSet(Set([notification.beginTrack, notification.endTrack].compactMap {$0}).compactMap {library.indexOfTrack($0)})
        //        let needToShowTrack: Bool = playQueueViewState.current == .tracks && preferences.showNewTrackInPlaylist
        let needToShowTrack: Bool = true
        
        if needToShowTrack {
            
            if let newTrack = notification.endTrack, let newTrackIndex = library.indexOfTrack(newTrack), newTrackIndex >= libraryView.numberOfRows {
                
                // This means the track is in the playlist but has not yet been added to the playlist view (Bookmark/Recently played/Favorite item), and will be added shortly (this is a race condition). So, dispatch an async delayed handler to show the track in the playlist, after it is expected to be added.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    self.showPlayingTrack()
                })
                
            } else {
                notification.endTrack != nil ? showPlayingTrack() : clearSelection()
            }
        }
        //
        //        // If this is not done async, the row view could get garbled.
        //        // (because of other potential simultaneous updates - e.g. PlayingTrackInfoUpdated)
        //        // Gaps may have been removed, so row heights need to be updated too
        DispatchQueue.main.async {
            self.libraryView.reloadData(forRowIndexes: refreshIndexes, columnIndexes: IndexSet(0..<self.libraryView.tableColumns.count))
        }
    }
    
    // Shows the currently playing track, within the playlist view
    private func showPlayingTrack() {
        
        if let playingTrack = playbackInfo.currentTrack, let playingTrackIndex = library.indexOfTrack(playingTrack) {
            selectTrack(playingTrackIndex)
        }
    }
    
    // Selects (and shows) a certain track within the playlist view
    private func selectTrack(_ index: Int) {
        
        if index >= 0 && index < rowCount {
            
            libraryView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            libraryView.scrollRowToVisible(index)
        }
    }
    
    private func clearSelection() {
        libraryView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }
    
    private func invertSelection() {
        libraryView.selectRowIndexes(invertedSelection, byExtendingSelection: false)
    }
    
    private var invertedSelection: IndexSet {
        IndexSet((0..<library.size).filter {!selectedRows.contains($0)})
    }
    
    private func cropSelection() {
        
        let tracksToDelete: IndexSet = invertedSelection
        
        if tracksToDelete.count > 0 {
            
            library.removeTracks(tracksToDelete)
            libraryView.reloadData()
            
            updateSummary()
        }
    }
    
    private func updateSummary() {
        
        let summary = library.summary
        let numTracks = summary.size
        
        lblTracksSummary.stringValue = String(format: "%d track%@", numTracks, numTracks == 1 ? "" : "s")
        lblDurationSummary.stringValue = ValueFormatter.formatSecondsToHMS(summary.totalDuration)
    }
    
    func refresh() {
        
        libraryView.reloadData()
        updateSummary()
    }
    
    private func removeSelectedTracks() {
        
        if atLeastOneSelectedRow {
            
            library.removeTracks(selectedRows)
            clearSelection()
        }
    }
    
    private func tracksRemoved(_ results: TrackRemovalResults) {
        
        let indexes = results.flatPlaylistResults
        guard !indexes.isEmpty else {return}
        
        // Tell the playlist view that the number of rows has changed (should result in removal of rows)
        libraryView.noteNumberOfRowsChanged()
        
        // Update all rows from the first (i.e. smallest index) removed row, down to the end of the playlist
        let firstRemovedRow = indexes.min()!
        let lastPlaylistRowAfterRemove = library.size - 1
        
        // This will be true unless a contiguous block of tracks was removed from the bottom of the playlist.
        if firstRemovedRow <= lastPlaylistRowAfterRemove {
            
            let refreshIndexes = IndexSet(firstRemovedRow...lastPlaylistRowAfterRemove)
            libraryView.reloadData(forRowIndexes: refreshIndexes, columnIndexes: IndexSet(0..<self.libraryView.tableColumns.count))
        }
        
        updateSummary()
    }
    
    // MARK: Scrolling ----------------------------------------------------------------
    
    // Scrolls the playlist view to the very top
    private func scrollToTop() {
        
        if atLeastOneRow {
            libraryView.scrollRowToVisible(0)
        }
    }
    
    // Scrolls the playlist view to the very bottom
    private func scrollToBottom() {
        
        if atLeastOneRow {
            libraryView.scrollRowToVisible(lastRow)
        }
    }
    
    private func pageUp() {
        
        if atLeastOneRow {
            libraryView.pageUp()
        }
    }
    
    private func pageDown() {
        
        if atLeastOneRow {
            libraryView.pageDown()
        }
    }
    
    // MARK: Appearance ----------------------------------------------------------------
    
    private func changeTextSize(_ textSize: TextSize) {
        
        let selectedRows = self.selectedRows
        libraryView.reloadData()
        libraryView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        
        lblTracksSummary.font = Fonts.Playlist.summaryFont
        lblDurationSummary.font = Fonts.Playlist.summaryFont
    }
    
    private func applyColorScheme(_ scheme: ColorScheme) {
        doApplyColorScheme(scheme)
    }
    
    private func doApplyColorScheme(_ scheme: ColorScheme, _ mustReloadRows: Bool = true) {
        
        changeBackgroundColor(scheme.general.backgroundColor)
        
        if mustReloadRows {
            
            let selectedRows = self.selectedRows
            libraryView.reloadData()
            libraryView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        }
        
        changeSummaryInfoColor(scheme.playlist.summaryInfoColor)
    }
    
    private func changeBackgroundColor(_ color: NSColor) {
        
        libraryView.enclosingScrollView?.backgroundColor = color
        libraryView.backgroundColor = color
        
        // Hack to redraw the top-right corner of the scroll view
        if libraryView.headerView != nil {
            
            libraryView.headerView = nil
            libraryView.headerView = header
        }
        
        scroller.redraw()
    }
    
    private var allRows: IndexSet {IndexSet(integersIn: 0..<rowCount)}
    
    private func changeTrackNameTextColor(_ color: NSColor) {
        libraryView.reloadData(forRowIndexes: allRows, columnIndexes: IndexSet(integer: 1))
    }
    
    private func changeIndexDurationTextColor(_ color: NSColor) {
        libraryView.reloadData(forRowIndexes: allRows, columnIndexes: IndexSet([0, 2]))
    }
    
    private func changeTrackNameSelectedTextColor(_ color: NSColor) {
        libraryView.reloadData(forRowIndexes: selectedRows, columnIndexes: IndexSet(integer: 1))
    }
    
    private func changeIndexDurationSelectedTextColor(_ color: NSColor) {
        libraryView.reloadData(forRowIndexes: selectedRows, columnIndexes: IndexSet([0, 2]))
    }
    
    private func changeSummaryInfoColor(_ color: NSColor) {
        [lblTracksSummary, lblDurationSummary].forEach {$0.textColor = color}
    }
    
    private func changeSelectionBoxColor(_ color: NSColor) {
        
        // Note down the selected rows, clear the selection, and re-select the originally selected rows (to trigger a repaint of the selection boxes)
        let selectedRows = self.selectedRows
        
        if !selectedRows.isEmpty {
            
            clearSelection()
            libraryView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        }
    }
    
    private func changePlayingTrackIconColor(_ color: NSColor) {
        
        if let playingTrack = self.playbackInfo.currentTrack, let playingTrackIndex = library.indexOfTrack(playingTrack) {
            libraryView.reloadData(forRowIndexes: IndexSet(integer: playingTrackIndex), columnIndexes: IndexSet(integer: 0))
        }
    }
    
    // MARK: Track playback ------------------------------------------------------------------------------
    
    // Plays the track selected within the playlist, if there is one. If multiple tracks are selected, the first one will be chosen.
    @IBAction func playNowAction(_ sender: AnyObject) {
        playNow()
    }
    
    // TODO: When play now is invoked,
    // display a non-intrusive popover giving the user
    // the option to clear the tracks previously in the
    // play queue ... if there were any. And dimiss the
    // popover after a few seconds.
    func playNow(withDelay seconds: Double? = nil) {
        
        _ = playQueue.enqueueToPlayNow(selectedTracks)
        Messenger.publish(TrackPlaybackCommandNotification(index: 0, delay: seconds))
    }
    
    func playNext() {
        _ = playQueue.enqueueToPlayNext(selectedTracks)
    }
    
    func playLater() {
        _ = playQueue.enqueueToPlayLater(selectedTracks)
    }
    
    // MARK: Context menu handling -----------------------------------------------------------------
    
    private var selectedTracks: [Track] {
        libraryView.selectedRowIndexes.compactMap {self.library.trackAtIndex($0)}
    }
    
    @IBAction func playNowContextMenuAction(_ sender: AnyObject) {
        playNow()
    }
    
    @IBAction func playNextContextMenuAction(_ sender: AnyObject) {
        playNext()
    }
    
    @IBAction func playLaterContextMenuAction(_ sender: AnyObject) {
        playLater()
    }
}