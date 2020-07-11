import Foundation

protocol PlayQueueDelegateProtocol {
    
    var tracks: [Track] {get}
    var size: Int {get}
    var duration: Double {get}
    
    func indexOfTrack(_ track: Track) -> Int?
    
    func trackAtIndex(_ index: Int) -> Track?
    
    var summary: (size: Int, totalDuration: Double) {get}
    
    func search(_ searchQuery: SearchQuery) -> SearchResults
    
    // MARK: Mutating functions ---------------------------------------------------------------
    
    // Adds tracks to the end of the queue, i.e. "Play Later"
    func playLater(_ tracks: [Track]) -> [Int]
    
    // Adds tracks to the beginning of the queue, i.e. "Play Now"
    func playNow(_ tracks: [Track]) -> [Int]

    // Inserts tracks immediately after the current track, i.e. "Play Next"
    func playNext(_ tracks: [Track]) -> [Int]
    
    func removeTracks(_ indices: IndexSet) -> [Track]

    func moveTracksUp(_ indices: IndexSet) -> ItemMoveResults
    
    func moveTracksToTop(_ indices: IndexSet) -> ItemMoveResults
    
    func moveTracksDown(_ indices: IndexSet) -> ItemMoveResults
    
    func moveTracksToBottom(_ indices: IndexSet) -> ItemMoveResults
    
    func dropTracks(_ sourceIndices: IndexSet, _ dropIndex: Int) -> ItemMoveResults
    
    func clear()
}