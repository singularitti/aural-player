import XCTest
@testable import Aural

/*
    Unit tests for Player
 */
class PlayerTests: XCTestCase {
    
    private var player: Player!
    
    private var mockPlayerGraph: MockPlayerGraph!
    private var mockScheduler: MockScheduler!
    private var mockPlayerNode: MockPlayerNode!
    
    private var track: Track = Track(URL(fileURLWithPath: "/Dummy/Path"))
    
    override func setUp() {
        
        if player == nil {
            
            mockPlayerGraph = MockPlayerGraph()
            mockPlayerNode = (mockPlayerGraph.playerNode as! MockPlayerNode)
            mockScheduler = MockScheduler(mockPlayerNode)
            
            player = Player(mockPlayerGraph, mockScheduler)
        }
        
        reset()
    }
    
    private func reset() {
        
        player.stop()
        
        mockScheduler.reset()
        mockPlayerNode.resetMock()
        
        track.setDuration(300)
        
        XCTAssertEqual(player.state, PlaybackState.noTrack)
        XCTAssertNil(PlaybackSession.currentSession)
        XCTAssertFalse(mockScheduler.playTrackInvoked || mockScheduler.playLoopInvoked || mockScheduler.endLoopInvoked || mockScheduler.seekToTimeInvoked)
    }

    func testPlay_startTimeOnly() {
        
        let trackDuration: Double = 300
        
        for startPos: Double in [0, 0.76, 1, 3.29, 20, 35, 200, 299, 299.5, 299.999] {
            
            reset()
            doTestPlay(trackDuration: trackDuration, playStartPos: startPos)
        }
    }
    
    func testPlay_loop() {
        doTestPlay(trackDuration: 300, playStartPos: 20, playEndPos: 40)
    }
    
    private func doTestPlay(trackDuration: Double, playStartPos: Double, playEndPos: Double? = nil) {
        
        track.setDuration(trackDuration)
        
        player.play(track, playStartPos, playEndPos)
        
        let curSession: PlaybackSession? = PlaybackSession.currentSession
        
        XCTAssertNotNil(curSession)
        
        if let session = curSession {
            
            XCTAssertEqual(session.track, track)
            
            XCTAssertEqual(session.hasLoop() && session.hasCompleteLoop(), playEndPos != nil)
            XCTAssertEqual(session.loop != nil, playEndPos != nil)
            
            if let loop = session.loop {
                
                XCTAssertEqual(loop.startTime, playStartPos)
                XCTAssertEqual(loop.endTime, playEndPos)
                
                XCTAssertNotNil(mockScheduler.playLoop_session)
                
                if let playLoop_session = mockScheduler.playLoop_session {
                    XCTAssertEqual(playLoop_session, session)
                }
                
                XCTAssertEqual(mockScheduler.playLoop_beginPlayback, true)
                
            } else {
                
                XCTAssertNotNil(mockScheduler.playTrack_session)
                if let playTrack_session = mockScheduler.playTrack_session {
                    XCTAssertEqual(playTrack_session, session)
                }
                
                XCTAssertNotNil(mockScheduler.playTrack_startPosition)
                if let playTrack_startPos = mockScheduler.playTrack_startPosition {
                    XCTAssertEqual(playTrack_startPos, playStartPos)
                }
            }
        }
        
        XCTAssertEqual(player.state, PlaybackState.playing)
    }
    
    // MARK: attemptSeekToTime() tests ------------------------------------------------------------------------------------------
    
    func testAttemptSeekToTime_noLoop_timeLessThan0_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -5.12, pausedBeforeSeek: false, expectedSeekPosition: 0, loopRemovalExpected: false, trackPlaybackCompletionExpected: false)
    }
    
    func testAttemptSeekToTime_noLoop_timeLessThan0_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -5.12, pausedBeforeSeek: true, expectedSeekPosition: 0, loopRemovalExpected: false, trackPlaybackCompletionExpected: false)
    }
    
    func testAttemptSeekToTime_noLoop_validTime_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 27.89, pausedBeforeSeek: false, expectedSeekPosition: 27.89, loopRemovalExpected: false, trackPlaybackCompletionExpected: false)
    }
    
    func testAttemptSeekToTime_noLoop_validTime_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 27.89, pausedBeforeSeek: true, expectedSeekPosition: 27.89, loopRemovalExpected: false, trackPlaybackCompletionExpected: false)
    }
    
    func testAttemptSeekToTime_noLoop_timeGreaterThanDuration_playing() {

        // Track should complete playback
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 302.76, pausedBeforeSeek: false, expectedSeekPosition: 300, loopRemovalExpected: false, trackPlaybackCompletionExpected: true)
    }
    
    func testAttemptSeekToTime_noLoop_timeGreaterThanDuration_paused() {

        // Track should NOT complete playback
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 302.76, pausedBeforeSeek: true, expectedSeekPosition: 300, loopRemovalExpected: false, trackPlaybackCompletionExpected: false)
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeBefore0_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -2.67, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeBefore0_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -2.67, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeGreaterThanDuration_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 310.11, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeGreaterThanDuration_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 310.11, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeBeforeLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeBeforeLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeAfterLoopEnd_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeAfterLoopEnd_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeWithinLoop_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 32.43, pausedBeforeSeek: false, expectedSeekPosition: 32.43, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withCompleteLoop_timeWithinLoop_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 32.43, pausedBeforeSeek: true, expectedSeekPosition: 32.43, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeBefore0_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -2.67, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeBefore0_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: -2.67, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeGreaterThanDuration_playing() {
        
        // Track playback should complete
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 310.11, pausedBeforeSeek: false, expectedSeekPosition: 300, loopRemovalExpected: false, trackPlaybackCompletionExpected: true, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeGreaterThanDuration_paused() {
        
        // Track playback should NOT complete
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 310.11, pausedBeforeSeek: true, expectedSeekPosition: 300, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeBeforeLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: false, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeBeforeLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: true, expectedSeekPosition: 20, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeAfterLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: false, expectedSeekPosition: 56.78, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    func testAttemptSeekToTime_withIncompleteLoop_timeAfterLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: true, expectedSeekPosition: 56.78, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20))
    }
    
    // MARK: forceSeekToTime() tests ------------------------------------------------------------------------------------------
    
    
    func testForceSeekToTime_noLoop_validTime_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 27.89, pausedBeforeSeek: false, expectedSeekPosition: 27.89, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, forceSeek: true)
    }
    
    func testForceSeekToTime_noLoop_validTime_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 27.89, pausedBeforeSeek: true, expectedSeekPosition: 27.89, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, forceSeek: true)
    }
   
    func testForceSeekToTime_withCompleteLoop_timeBeforeLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: false, expectedSeekPosition: 10.59, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withCompleteLoop_timeBeforeLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: true, expectedSeekPosition: 10.59, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withCompleteLoop_timeAfterLoopEnd_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: false, expectedSeekPosition: 56.78, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withCompleteLoop_timeAfterLoopEnd_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: true, expectedSeekPosition: 56.78, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withCompleteLoop_timeWithinLoop_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 32.43, pausedBeforeSeek: false, expectedSeekPosition: 32.43, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withCompleteLoop_timeWithinLoop_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 32.43, pausedBeforeSeek: true, expectedSeekPosition: 32.43, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20, 40), forceSeek: true)
    }
    
    func testForceSeekToTime_withIncompleteLoop_timeBeforeLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: false, expectedSeekPosition: 10.59, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20), forceSeek: true)
    }
    
    func testForceSeekToTime_withIncompleteLoop_timeBeforeLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 10.59, pausedBeforeSeek: true, expectedSeekPosition: 10.59, loopRemovalExpected: true, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20), forceSeek: true)
    }
    
    func testForceSeekToTime_withIncompleteLoop_timeAfterLoopStart_playing() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: false, expectedSeekPosition: 56.78, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20), forceSeek: true)
    }
    
    func testForceSeekToTime_withIncompleteLoop_timeAfterLoopStart_paused() {
        
        doTestSeekToTime(trackDuration: 300, playStartPos: 0, desiredSeekTime: 56.78, pausedBeforeSeek: true, expectedSeekPosition: 56.78, loopRemovalExpected: false, trackPlaybackCompletionExpected: false, playbackLoop: PlaybackLoop(20), forceSeek: true)
    }
    
    private func doTestSeekToTime(trackDuration: Double, playStartPos: Double, desiredSeekTime: Double, pausedBeforeSeek: Bool, expectedSeekPosition: Double, loopRemovalExpected: Bool, trackPlaybackCompletionExpected: Bool, playbackLoop: PlaybackLoop? = nil, forceSeek: Bool = false) {
        
        track.setDuration(trackDuration)
        
        // Play and pause track
        player.play(track, playStartPos)
        
        if pausedBeforeSeek {
            player.pause()
        }
        
        // Define a loop if necessary
        if let loop = playbackLoop {
            
            PlaybackSession.beginLoop(loop.startTime)
            
            if let loopEndTime = loop.endTime {
                PlaybackSession.endLoop(loopEndTime)
            }
        }
        
        // Validate the resulting playback session
        let curSession: PlaybackSession? = PlaybackSession.currentSession
        
        XCTAssertNotNil(curSession)
        
        if let session = curSession {
            XCTAssertEqual(session.track, track)
        }
        
        // Seek
        let seekResult = forceSeek ? player.forceSeekToTime(track, desiredSeekTime) : player.attemptSeekToTime(track, desiredSeekTime)
        
        // Validate the seek result
        XCTAssertEqual(seekResult.actualSeekPosition, expectedSeekPosition)
        XCTAssertEqual(seekResult.loopRemoved, loopRemovalExpected)
        XCTAssertEqual(seekResult.trackPlaybackCompleted, trackPlaybackCompletionExpected)
        
        // Validate the resulting playback state
        XCTAssertEqual(player.state, pausedBeforeSeek ? PlaybackState.paused : PlaybackState.playing)
    }
    
    // MARK: seekPosition tests ------------------------------------------------------------------------------------
    
    func testSeekPosition_noTrack() {
        
        mockScheduler.seekPosition = 15
        
        // The scheduler's seek position should be ignored
        XCTAssertEqual(player.seekPosition, 0)
    }
    
    func testSeekPosition_playing() {
        
        _ = doPlay(track, 0)
        
        mockScheduler.seekPosition = 15
        XCTAssertEqual(player.seekPosition, mockScheduler.seekPosition)
    }
    
    func testSeekPosition_paused() {
        
        let sessionBeforePause: PlaybackSession = doPlay(track, 0)
        _ = doPause(track, sessionBeforePause)
        
        mockScheduler.seekPosition = 15
        XCTAssertEqual(player.seekPosition, mockScheduler.seekPosition)
    }
    
    func testSeekPosition_waiting() {
        
        player.waiting()
        
        mockScheduler.seekPosition = 15
        
        // The scheduler's seek position should be ignored
        XCTAssertEqual(player.seekPosition, 0)
    }
    
    func testSeekPosition_transcoding() {
        
        player.transcoding()
        
        mockScheduler.seekPosition = 15
        
        // The scheduler's seek position should be ignored
        XCTAssertEqual(player.seekPosition, 0)
    }
    
    // MARK: pause(), resume(), stop() tests ------------------------------------------------------------------------------------
    
    func testPause() {
        
        // Play
        let sessionBeforePause: PlaybackSession = doPlay(track, 0)

        // Pause
        _ = doPause(track, sessionBeforePause)
    }
    
    func testResume() {
        
        // Play
        let sessionBeforePause: PlaybackSession = doPlay(track, 0)

        // Pause
        let sessionBeforeResume: PlaybackSession = doPause(track, sessionBeforePause)
        
        // Resume
        _ = doResume(track, sessionBeforeResume)
    }
    
    func testStop_whenPlaying() {
        
        // Play
        let sessionBeforeStop: PlaybackSession = doPlay(track, 0)
        
        // Stop
        doStop(track, sessionBeforeStop)
    }
    
    func testStop_whenPaused() {
        
        // Play
        let sessionBeforePause: PlaybackSession = doPlay(track, 0)
        
        // Pause
        let sessionBeforeStop: PlaybackSession = doPause(track, sessionBeforePause)
        
        // Stop
        doStop(track, sessionBeforeStop)
    }
    
    func testStop_afterPlayPauseResume() {
        
        // Play
        let sessionBeforePause: PlaybackSession = doPlay(track, 0)
        
        // Pause
        let sessionBeforeResume: PlaybackSession = doPause(track, sessionBeforePause)
        
        // Resume
        let sessionBeforeStop: PlaybackSession = doResume(track, sessionBeforeResume)
        
        // Stop
        doStop(track, sessionBeforeStop)
    }
    
    private func doPlay(_ track: Track, _ startPos: Double) -> PlaybackSession {
        
        player.play(track, startPos)
        XCTAssertNotNil(PlaybackSession.currentSession)
        
        if let sessionAfterPlay = PlaybackSession.currentSession {
            XCTAssertEqual(sessionAfterPlay.track, track)
        }
        
        XCTAssertEqual(player.state, PlaybackState.playing)
        return PlaybackSession.currentSession!
    }
    
    private func doPause(_ track: Track, _ sessionBeforePause: PlaybackSession) -> PlaybackSession {
        
        XCTAssertFalse(mockScheduler.paused)
        
        player.pause()
        XCTAssertNotNil(PlaybackSession.currentSession)

        // Ensure session is still the same one
        if let sessionAfterPause = PlaybackSession.currentSession {
            
            XCTAssertEqual(sessionAfterPause.track, track)
            XCTAssertEqual(sessionAfterPause, sessionBeforePause)
        }
        
        XCTAssertTrue(mockScheduler.paused)
        XCTAssertEqual(player.state, PlaybackState.paused)
        
        return PlaybackSession.currentSession!
    }
    
    private func doResume(_ track: Track, _ sessionBeforeResume: PlaybackSession) -> PlaybackSession {
        
        XCTAssertFalse(mockScheduler.resumed)
        
        player.resume()
        XCTAssertNotNil(PlaybackSession.currentSession)
        
        // Ensure session is still the same one
        if let sessionAfterResume = PlaybackSession.currentSession  {
            
            XCTAssertEqual(sessionAfterResume.track, track)
            XCTAssertEqual(sessionAfterResume, sessionBeforeResume)
        }
        
        XCTAssertTrue(mockScheduler.resumed)
        XCTAssertEqual(player.state, PlaybackState.playing)
        
        return PlaybackSession.currentSession!
    }
    
    private func doStop(_ track: Track, _ sessionBeforeStop: PlaybackSession) {

        XCTAssertFalse(mockScheduler.stopped)
        
        player.stop()
        
        XCTAssertNil(PlaybackSession.currentSession)
        XCTAssertTrue(mockScheduler.stopped)
        XCTAssertEqual(player.state, PlaybackState.noTrack)
    }
    
    func testWaiting() {
        
        player.waiting()
        XCTAssertEqual(player.state, PlaybackState.waiting)
    }
    
    func testTranscoding() {
        
        player.transcoding()
        XCTAssertEqual(player.state, PlaybackState.transcoding)
    }
    
    // MARK: defineLoop() tests ------------------------------------------------------------------------------------
    
    func testDefineLoop_noTrack() {
        
        // This should have no effect, because no track is currently playing.
        player.defineLoop(20, 40)
        
        XCTAssertNil(PlaybackSession.currentSession)
        XCTAssertNil(PlaybackSession.currentLoop)
        XCTAssertFalse(mockScheduler.playLoopInvoked)
    }
    
    func testDefineLoop_noLoopDefined_playing() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)
        
        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, nil, false)
    }
    
    func testDefineLoop_incompleteLoopDefined_playing() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)
        
        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, PlaybackLoop(56.78), false)
    }
    
    func testDefineLoop_completeLoopDefined_playing() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)

        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, PlaybackLoop(56.78, 77.25), false)
    }
    
    func testDefineLoop_noLoopDefined_paused() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)
        
        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, nil, true)
    }
    
    func testDefineLoop_incompleteLoopDefined_paused() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)
        
        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, PlaybackLoop(56.78), true)
    }
    
    func testDefineLoop_completeLoopDefined_paused() {
        
        // Play
        let sessionBeforeDefiningLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeDefiningLoop.loop)

        // defineLoop()
        doDefineLoop(sessionBeforeDefiningLoop, 20, 40, 32, PlaybackLoop(56.78, 77.25), true)
    }
    
    // Assumes a track is playing (and there is a current session).
    private func doDefineLoop(_ sessionBeforeDefiningLoop: PlaybackSession, _ loopStartTime: Double, _ loopEndTime: Double, _ seekPosition: Double, _ preDefinedLoop: PlaybackLoop?, _ paused: Bool) {
        
        // Pre-define a loop if necessary
        if let loop = preDefinedLoop {
            
            PlaybackSession.beginLoop(loop.startTime)
            
            if let loopEndTime = loop.endTime {
                PlaybackSession.endLoop(loopEndTime)
            }
            
            XCTAssertNotNil(sessionBeforeDefiningLoop.loop)
        }
        
        // Pause if necessary
        if paused {
            
            player.pause()
            XCTAssertEqual(player.state, PlaybackState.paused)
        }
        
        // Call defineLoop()
        mockScheduler.seekPosition = seekPosition
        player.defineLoop(loopStartTime, loopEndTime)
        
        let sessionAfterDefiningLoop = PlaybackSession.currentSession
        XCTAssertNotNil(sessionAfterDefiningLoop)
        
        // The 2 sessions should be different, but be associated with the same track
        XCTAssertNotEqual(sessionBeforeDefiningLoop, sessionAfterDefiningLoop)
        XCTAssertEqual(sessionBeforeDefiningLoop.track, sessionAfterDefiningLoop?.track)
        
        if let newSession = sessionAfterDefiningLoop {
            
            XCTAssertEqual(newSession.track, track)
            XCTAssertNotNil(newSession.loop)
            
            if let loopAfter = newSession.loop {
                
                XCTAssertEqual(loopAfter.startTime, loopStartTime)
                XCTAssertEqual(loopAfter.endTime, loopEndTime)
            }
            
            XCTAssertTrue(mockScheduler.playLoopInvoked)
            XCTAssertEqual(mockScheduler.playLoop_session, newSession)
            XCTAssertEqual(mockScheduler.playLoop_startTime, mockScheduler.seekPosition)
            XCTAssertEqual(mockScheduler.playLoop_beginPlayback, !paused)
        }
        
        // Playback state from before the call should be unchanged.
        XCTAssertEqual(player.state, paused ? PlaybackState.paused : PlaybackState.playing)
    }
    
    // MARK: toggleLoop() tests ------------------------------------------------------------------------------------
    
    func testToggleLoop_noLoopDefined_playing() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)
        
        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 32, nil, false)
    }
    
    func testToggleLoop_incompleteLoopDefined_playing() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)
        
        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 65.987, PlaybackLoop(56.78), false)
    }
    
    func testToggleLoop_completeLoopDefined_playing() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)

        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 69.82, PlaybackLoop(56.78, 77.25), false)
    }
    
    func testToggleLoop_noLoopDefined_paused() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)
        
        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 32, nil, true)
    }
    
    func testToggleLoop_incompleteLoopDefined_paused() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)
        
        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 65.987, PlaybackLoop(56.78), true)
    }
    
    func testToggleLoop_completeLoopDefined_paused() {
        
        // Play
        let sessionBeforeTogglingLoop = doPlay(track, 0)
        XCTAssertNil(sessionBeforeTogglingLoop.loop)

        // toggleLoop()
        doToggleLoop(sessionBeforeTogglingLoop, 69.82, PlaybackLoop(56.78, 77.25), true)
    }
    
    // Assumes a track is playing (and there is a current session).
    private func doToggleLoop(_ sessionBeforeTogglingLoop: PlaybackSession, _ seekPosition: Double, _ preDefinedLoop: PlaybackLoop?, _ paused: Bool) {
        
        // Pre-define a loop if necessary
        if let loop = preDefinedLoop {
            
            PlaybackSession.beginLoop(loop.startTime)
            
            if let loopEndTime = loop.endTime {
                PlaybackSession.endLoop(loopEndTime)
            }
            
            XCTAssertNotNil(sessionBeforeTogglingLoop.loop)
        }
        
        // Pause if necessary
        if paused {
            
            player.pause()
            XCTAssertEqual(player.state, PlaybackState.paused)
        }
        
        // Call toggleLoop()
        mockScheduler.seekPosition = seekPosition
        let loopReturnedAfterToggle = player.toggleLoop()
        let sessionAfterTogglingLoop = PlaybackSession.currentSession
        
        XCTAssertNotNil(sessionAfterTogglingLoop)
        XCTAssertEqual(sessionBeforeTogglingLoop.track, sessionAfterTogglingLoop?.track)
        XCTAssertEqual(loopReturnedAfterToggle, sessionAfterTogglingLoop?.loop)
        
        // Switch based on pre-defined loop state
        
        if preDefinedLoop == nil {
            
            // toggleLoop() should have begun a new loop at the current seek position, with no change in session.
            
            XCTAssertNotNil(loopReturnedAfterToggle)
            
            XCTAssertEqual(sessionBeforeTogglingLoop, sessionAfterTogglingLoop)
            XCTAssertEqual(loopReturnedAfterToggle!.startTime, seekPosition)
            XCTAssertNil(loopReturnedAfterToggle!.endTime)
            
            XCTAssertFalse(mockScheduler.playLoopInvoked || mockScheduler.endLoopInvoked)
            
        } else if preDefinedLoop?.isComplete ?? false {
            
            // toggleLoop() should have removed the previously defined complete loop and created a new playback session for the same track.
            
            XCTAssertNil(loopReturnedAfterToggle)
            XCTAssertNotEqual(sessionBeforeTogglingLoop, sessionAfterTogglingLoop)
            
            XCTAssertTrue(mockScheduler.endLoopInvoked)
            XCTAssertEqual(mockScheduler.endLoop_session, sessionAfterTogglingLoop)
            XCTAssertEqual(mockScheduler.endLoop_loopEndTime, preDefinedLoop!.endTime!)
            
        } else {
            
            // toggleLoop() should have marked an end time (at the current seek position) for the previously incomplete loop, thus completing it, and have created a new playback session for the same track.
            
            XCTAssertNotNil(loopReturnedAfterToggle)
            
            XCTAssertNotEqual(sessionBeforeTogglingLoop, sessionAfterTogglingLoop)
            
            XCTAssertEqual(loopReturnedAfterToggle!.startTime, preDefinedLoop!.startTime)
            XCTAssertEqual(loopReturnedAfterToggle!.endTime, seekPosition)
            
            XCTAssertTrue(mockScheduler.playLoopInvoked)
            XCTAssertEqual(mockScheduler.playLoop_session, sessionAfterTogglingLoop)
            XCTAssertEqual(mockScheduler.playLoop_startTime, preDefinedLoop?.startTime)
            XCTAssertEqual(mockScheduler.playLoop_beginPlayback, !paused)
        }
        
        // Playback state from before the call should be unchanged.
        XCTAssertEqual(player.state, paused ? PlaybackState.paused : PlaybackState.playing)
    }
    
    // MARK: playbackLoop tests -----------------------------------------------------------------------
    
    func testPlaybackLoop_noTrack() {
        
        XCTAssertEqual(player.state, PlaybackState.noTrack)
        XCTAssertNil(player.playbackLoop)
    }
    
    func testPlaybackLoop_noLoop() {

        _ = doPlay(track, 0)
        XCTAssertNil(player.playbackLoop)
    }
    
    func testPlaybackLoop_incompleteLoop() {

        _ = doPlay(track, 0)
        
        let loopStartTime: Double = 20
        PlaybackSession.beginLoop(loopStartTime)
        
        let playbackLoop = player.playbackLoop
        XCTAssertNotNil(playbackLoop)
        
        XCTAssertEqual(playbackLoop, PlaybackSession.currentLoop)
        XCTAssertEqual(playbackLoop?.startTime, loopStartTime)
        XCTAssertEqual(playbackLoop?.isComplete, false)
    }
    
    func testPlaybackLoop_completeLoop() {

        _ = doPlay(track, 0)
        
        let loopStartTime: Double = 20
        let loopEndTime: Double = 40
        
        PlaybackSession.beginLoop(loopStartTime)
        PlaybackSession.endLoop(loopEndTime)
        
        let playbackLoop = player.playbackLoop
        XCTAssertNotNil(playbackLoop)
        
        XCTAssertEqual(playbackLoop, PlaybackSession.currentLoop)
        
        XCTAssertEqual(playbackLoop?.startTime, loopStartTime)
        XCTAssertEqual(playbackLoop?.endTime, loopEndTime)
        
        XCTAssertEqual(playbackLoop?.isComplete, true)
    }
}
