import Foundation

class PlaybackChain {
    
    var actions: [PlaybackChainAction] = []
    
    func withAction(_ action: PlaybackChainAction) -> PlaybackChain {
        
        var lastAction = actions.last
        actions.append(action)
        lastAction?.nextAction = action
        
        return self
    }
    
    func execute(_ context: PlaybackRequestContext) {
        
        context.begun()
        
        if let firstAction = actions.first {
            firstAction.execute(context)
        }
    }
}

protocol PlaybackChainAction {
    
    func execute(_ context: PlaybackRequestContext)

    // The next action in the playback chain. Will be executed by this action object,
    // if execution of this object's action was completed successfully and further execution
    // of the playback chain has not been deferred.
    var nextAction: PlaybackChainAction? {get set}
}