import Cocoa

class PlayingTrackFunctionsViewController: NSViewController, MessageSubscriber, ActionMessageSubscriber, AsyncMessageSubscriber {
    
    // Button to display more details about the playing track
    @IBOutlet weak var btnMoreInfo: TintedImageButton!
    
    // Button to add/remove the currently playing track to/from the Favorites list
    @IBOutlet weak var btnFavorite: OnOffImageButton!
    
    // Button to bookmark current track and position
    @IBOutlet weak var btnBookmark: TintedImageButton!
    
    @IBOutlet weak var btnShowPlayingTrackInPlaylist: TintedImageButton!
    
    // Delegate that provides info about the playing track
    private lazy var player: PlaybackInfoDelegateProtocol = ObjectGraph.playbackInfoDelegate
    
    // Delegate that provides access to History information
    private lazy var favorites: FavoritesDelegateProtocol = ObjectGraph.favoritesDelegate
    
    // Popover view that displays detailed info for the currently playing track
    private lazy var detailedInfoPopover: PopoverViewDelegate = ViewFactory.detailedTrackInfoPopover
    
    private lazy var windowManager: WindowManagerProtocol = ObjectGraph.windowManager
    
    // Popup view that displays a brief notification when the currently playing track is added/removed to/from the Favorites list
    private lazy var infoPopup: InfoPopupProtocol = ViewFactory.infoPopup
    
    private lazy var bookmarks: BookmarksDelegateProtocol = ObjectGraph.bookmarksDelegate
    private lazy var bookmarkNamePopover: StringInputPopoverViewController = StringInputPopoverViewController.create(BookmarkNameInputReceiver())
    
    override var nibName: String? {return "PlayingTrackFunctions"}
    
    private var allButtons: [Tintable] = []
    
    override func viewDidLoad() {
        
        allButtons = [btnMoreInfo, btnShowPlayingTrackInPlaylist, btnFavorite, btnBookmark]
        
        // Subscribe to various notifications
        
        AsyncMessenger.subscribe([.addedToFavorites, .removedFromFavorites], subscriber: self, dispatchQueue: DispatchQueue.main)
        
        SyncMessenger.subscribe(actionTypes: [.moreInfo, .bookmarkPosition, .bookmarkLoop, .applyColorScheme, .changeFunctionButtonColor, .changeToggleButtonOffStateColor], subscriber: self)
        
        SyncMessenger.subscribe(messageTypes: [.trackChangedNotification], subscriber: self)
    }
    
    // Shows a popover with detailed information for the currently playing track, if there is one
    @IBAction func moreInfoAction(_ sender: AnyObject) {
        
        // If there is a track currently playing, load detailed track info and toggle the popover view
        if let playingTrack = player.playingTrack?.track {
            
            if detailedInfoPopover.isShown {
                
                detailedInfoPopover.close()
                
            } else {
                
                // TODO: This should be done through a delegate (TrackDelegate ???)
                playingTrack.loadDetailedInfo()
                
                windowManager.mainWindow.makeKeyAndOrderFront(self)
                
                let autoHideIsOn: Bool = PlayerViewState.viewType == .expandedArt || !PlayerViewState.showControls
                
                if btnMoreInfo.isVisible && !autoHideIsOn {
                    
                    detailedInfoPopover.show(playingTrack, btnMoreInfo, NSRectEdge.maxX)
                    
                } else if let windowRootView = self.view.window?.contentView {
                    
                    detailedInfoPopover.show(playingTrack, windowRootView, NSRectEdge.maxX)
                }
            }
        }
    }
    
    // Shows (selects) the currently playing track, within the playlist, if there is one
    @IBAction func showPlayingTrackAction(_ sender: Any) {
        SyncMessenger.publishActionMessage(PlaylistActionMessage(.showPlayingTrack, PlaylistViewState.current))
    }
    
    // Adds/removes the currently playing track to/from the "Favorites" list
    @IBAction func favoriteAction(_ sender: Any) {
        
        if let playingTrack = player.playingTrack?.track {
            
            // Toggle the button state
            btnFavorite.toggle()
            
            // Publish an action message to add/remove the item to/from Favorites
            btnFavorite.isOn ? _ = favorites.addFavorite(playingTrack) : favorites.deleteFavoriteWithFile(playingTrack.file)
        }
    }
    
    // Adds the currently playing track position to/from the "Bookmarks" list
    @IBAction func bookmarkAction(_ sender: Any) {
        
        if let playingTrack = player.playingTrack?.track {
            doBookmark(playingTrack, player.seekPosition.timeElapsed)
        }
    }
    
    // When a bookmark menu item is clicked, the item is played
    private func bookmarkLoop() {
        
        // Check if we have a complete loop
        if let playingTrack = player.playingTrack?.track, let loop = player.playbackLoop, let loopEndTime = loop.endTime {
            doBookmark(playingTrack, loop.startTime, loopEndTime)
        }
    }
    
    private func doBookmark(_ playingTrack: Track, _ startTime: Double, _ endTime: Double? = nil) {
        
        BookmarkContext.bookmarkedTrack = playingTrack
        BookmarkContext.bookmarkedTrackStartPosition = startTime
        BookmarkContext.bookmarkedTrackEndPosition = endTime
        
        if let theEndTime = endTime {
            
            // Loop
            BookmarkContext.defaultBookmarkName = String(format: "%@ (%@ ⇄ %@)", playingTrack.conciseDisplayName, ValueFormatter.formatSecondsToHMS(startTime), ValueFormatter.formatSecondsToHMS(theEndTime))
            
        } else {
            
            // Single position
            BookmarkContext.defaultBookmarkName = String(format: "%@ (%@)", playingTrack.conciseDisplayName, ValueFormatter.formatSecondsToHMS(startTime))
        }
        
        // Show popover
        
        let autoHideIsOn: Bool = PlayerViewState.viewType == .expandedArt || !PlayerViewState.showControls
        
        windowManager.mainWindow.makeKeyAndOrderFront(self)
        
        // If controls are being auto-hidden, don't display popover relative to any view within the window. Show it relative to the window itself.
        if autoHideIsOn {

            // Show popover relative to window
            if let windowRootView = self.view.window?.contentView {
                bookmarkNamePopover.show(windowRootView, NSRectEdge.maxX)
            }
            
        } else {
            
            let seekPositionMarkerView: NSView = ViewFactory.seekPositionMarkerView
            
            // Show popover relative to seek slider
            if seekPositionMarkerView.isVisible {
                bookmarkNamePopover.show(seekPositionMarkerView, NSRectEdge.maxY)

            } // Show popover relative to bookmark function button
            else if btnBookmark.isVisible {
                bookmarkNamePopover.show(btnBookmark, NSRectEdge.maxX)
                
            } // Show popover relative to window
            else if let windowRootView = self.view.window?.contentView {
                bookmarkNamePopover.show(windowRootView, NSRectEdge.maxX)
            }
        }
    }
    
    // Responds to a notification that a track has been added to / removed from the Favorites list, by updating the UI to reflect the new state
    private func favoritesUpdated(_ message: FavoritesUpdatedAsyncMessage) {
        
        // Do this only if the track in the message is the playing track
        if let playingTrack = player.playingTrack?.track, message.file.path == playingTrack.file.path {
            
            let added: Bool = message.messageType == .addedToFavorites
            
            windowManager.mainWindow.makeKeyAndOrderFront(self)
            
            btnFavorite.onIf(added)
            
            let autoHideIsOn: Bool = PlayerViewState.viewType == .expandedArt || !PlayerViewState.showControls
            
            if btnFavorite.isVisible && !autoHideIsOn {
                
                infoPopup.showMessage(added ? "Track added to Favorites !" : "Track removed from Favorites !", btnFavorite, NSRectEdge.maxX)
                
            } else if let windowRootView = self.view.window?.contentView {
                
                infoPopup.showMessage(added ? "Track added to Favorites !" : "Track removed from Favorites !", windowRootView, NSRectEdge.maxX)
            }
        }
    }
    
    private func newTrackStarted(_ track: Track) {
        
        self.view.showIf(PlayerViewState.showPlayingTrackFunctions)
        btnFavorite.onIf(favorites.favoriteWithFileExists(track.file))
    }
    
    private func noTrackPlaying() {
        
        detailedInfoPopover.close()
        self.view.hide()
    }
    
    private func trackChanged(_ notification: TrackChangedNotification) {
        trackChanged(notification.newTrack, notification.errorState)
    }
    
    // The "errorState" arg indicates whether the player is in an error state (i.e. the new track cannot be played back). If so, update the UI accordingly.
    private func trackChanged(_ newTrack: IndexedTrack?, _ errorState: Bool = false) {
        
        if let track = newTrack?.track {
            
            newTrackStarted(track)
            
            if !errorState && detailedInfoPopover.isShown {
                
                track.loadDetailedInfo()
                detailedInfoPopover.refresh(track)
            }
            
        } else {
            
            // No track playing, clear the info fields
            noTrackPlaying()
        }
    }
    
    private func applyColorScheme(_ scheme: ColorScheme) {
        allButtons.forEach({$0.reTint()})
    }
    
    private func changeFunctionButtonColor() {
        allButtons.forEach({$0.reTint()})
    }
    
    private func changeToggleButtonOffStateColor() {
        btnFavorite.reTint()
    }
    
    // MARK: Message handling
    
    var subscriberId: String {
        return self.className
    }
    
    func consumeNotification(_ notification: NotificationMessage) {
        
        if let trackChangeNotification = notification as? TrackChangedNotification {

            trackChanged(trackChangeNotification)
            return
        }
    }
    
    // Consume asynchronous messages
    func consumeAsyncMessage(_ message: AsyncMessage) {
        
        if let favsUpdatedMsg = message as? FavoritesUpdatedAsyncMessage {
            
            favoritesUpdated(favsUpdatedMsg)
            return
        }
    }
    
    func consumeMessage(_ message: ActionMessage) {
        
        switch message.actionType {
            
        case .moreInfo: moreInfoAction(self)
        
        case .bookmarkPosition: bookmarkAction(self)
            
        case .bookmarkLoop: bookmarkLoop()
            
        case .applyColorScheme:
        
        if let colorSchemeActionMsg = message as? ColorSchemeActionMessage {
            applyColorScheme(colorSchemeActionMsg.scheme)
        }
        
        case .changeFunctionButtonColor:
               
            changeFunctionButtonColor()
            
        case .changeToggleButtonOffStateColor:
            
            changeToggleButtonOffStateColor()

        default: return
            
        }
    }
}