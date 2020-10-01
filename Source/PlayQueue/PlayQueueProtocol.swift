import Foundation

protocol PlayQueueProtocol: SequencingProtocol {
    
    var tracks: [Track] {get}
    var size: Int {get}
    var duration: Double {get}
    
    func indexOfTrack(_ track: Track) -> Int?
    
    func trackAtIndex(_ index: Int) -> Track?
    
    var summary: (size: Int, totalDuration: Double) {get}
    
    func search(_ searchQuery: SearchQuery) -> SearchResults
    
    // MARK: Mutating functions ---------------------------------------------------------------
    
    // Adds tracks to the end of the queue, i.e. "Play Later"
    func enqueue(_ tracks: [Track]) -> ClosedRange<Int>
    
    // Adds tracks to the beginning of the queue, i.e. "Play Now"
    func enqueueAtHead(_ tracks: [Track]) -> ClosedRange<Int>

    // Inserts tracks immediately after the current track, i.e. "Play Next"
    func enqueueAfterCurrentTrack(_ tracks: [Track]) -> ClosedRange<Int>
    
    func removeTracks(_ indices: IndexSet) -> [Track]

    func moveTracksUp(_ indices: IndexSet) -> [TrackMoveResult]
    
    func moveTracksToTop(_ indices: IndexSet) -> [TrackMoveResult]
    
    func moveTracksDown(_ indices: IndexSet) -> [TrackMoveResult]
    
    func moveTracksToBottom(_ indices: IndexSet) -> [TrackMoveResult]
    
    func dropTracks(_ sourceIndices: IndexSet, _ dropIndex: Int) -> [TrackMoveResult]
    
    func clear()
    
    func sort(_ sort: Sort) -> SortResults
    
    func sort(by comparator: (Track, Track) -> Bool)
}

/*
    Contract for a sequencer that provides convenient CRUD access to the playback sequence to select tracks/groups for playback and/or determine which track will play next.
 */
protocol SequencingProtocol {
    
    /*
     
     NOTE - "Subsequent track" is the track in the sequence that will be selected automatically by the app if playback of a track completes. It involves no user input.
     
     By contrast, "Next track" is the track in the sequence that will be selected if the user requests the next track in the sequence. This may or may not be the same as the "Subsequent track"
     */
    
    // NOTE - Nil return values mean no applicable track
    
    // Begins a new playback sequence, and selects, for playback, the first track in that sequence. This function will be called only when no track is currently playing and no specific track/group is selected by the user for playback. For ex, when the user just hits the play button and no track is currently playing.
    // NOTE - This function will always create a sequence that contains all playlist tracks - e.g. All tracks, All artists, etc.
    func begin() -> Track?
    
    // Ends the current playback sequence (when playback is stopped or the last track in the sequence has finished playing)
    func end()
    
    // Selects, for playback, the subsequent track in the sequence
    func subsequent() -> Track?
    
    // Selects, for playback, the previous track in the sequence
    func previous() -> Track?
    
    // Selects, for playback, the next track in the sequence
    func next() -> Track?
    
    // Peeks at (without selecting for playback) the subsequent track in the sequence
    func peekSubsequent() -> Track?
    
    // Peeks at (without selecting for playback) the previous track in the sequence
    func peekPrevious() -> Track?
    
    // Peeks at (without selecting for playback) the next track in the sequence
    func peekNext() -> Track?
    
    /*
        Selects, for playback, the track with the given index in the flat "Tracks" playlist. This implies that the sequence consists of all tracks within the flat "Tracks playlist, and that the sequence will begin with this track.
     
        NOTE - When a single index is specified, it is implied that the playlist from which this request originated was the flat "Tracks" playlist, because this playlist locates tracks by a single absolute index. Hence, this function is intended to be called only when playback originates from the "Tracks" playlist.
    */
    func select(_ index: Int) -> Track?
    
    /*
        Selects, for playback, the specified track. When this function is called, a new sequence will be created, consisting of:
     
        - either all tracks in the group (artist/album/genre) that this track is a child of,
        - OR all tracks in the flat "Tracks" playlist,
     
        depending on where the request originated from.
     */
    func select(_ track: Track) -> Track?
    
    /*
        Selects, for playback, the specified group, which implies playback of all tracks within this group. The first track determined by the playback sequence (dependent upon the repeat/shuffle modes) will be selected for playback and returned.
     
        NOTE - When a group is specified, it is implied that the playlist from which this request originated was a grouping/hierarchical playlist, because such a playlist does not provide a single index to locate an item. It provides either a track or a group. Hence, this function is intended to be called only when playback originates from one of the grouping/hierarchical playlists.
     */
//    func select(_ group: Group) -> Track?
    
    // Returns the currently selected track (which could be playing / paused / waiting / transcoding)
    var currentTrack: Track? {get}
    
    // Toggles between repeat modes. Returns the new repeat and shuffle mode after performing the toggle operation.
    func toggleRepeatMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode)
    
    // Toggles between shuffle modes. Returns the new repeat and shuffle mode after performing the toggle operation.
    func toggleShuffleMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode)
    
    // Sets the repeat mode to a specific value. Returns the new repeat and shuffle mode after performing the toggle operation.
    func setRepeatMode(_ repeatMode: RepeatMode) -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode)
    
    // Sets the shuffle mode to a specific value. Returns the new repeat and shuffle mode after performing the toggle operation.
    func setShuffleMode(_ shuffleMode: ShuffleMode) -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode)
    
    // Returns the current repeat and shuffle modes
    var repeatAndShuffleModes: (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {get}
}