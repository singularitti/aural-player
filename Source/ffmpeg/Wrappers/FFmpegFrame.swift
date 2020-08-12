import AVFoundation
import Accelerate

///
/// Encapsulates an ffmpeg AVFrame struct that represents a single (decoded) frame,
/// i.e. audio data in its raw decoded / uncompressed form, post-decoding,
/// and provides convenient Swift-style access to its functions and member variables.
///
class FFmpegFrame {
 
    ///
    /// The encapsulated AVFrame object.
    ///
    var avFrame: AVFrame {pointer.pointee}
    
    ///
    /// A pointer to the encapsulated AVFrame object.
    ///
    var pointer: UnsafeMutablePointer<AVFrame>!
    
    ///
    /// Describes the number and physical / spatial arrangement of the channels. (e.g. "5.1 surround" or "stereo")
    ///
    var channelLayout: UInt64 {avFrame.channel_layout}
    
    ///
    /// Number of channels of audio data.
    ///
    var channelCount: Int32 {avFrame.channels}

    ///
    /// PCM format of the samples.
    ///
    var sampleFormat: FFmpegSampleFormat
    
    ///
    /// Total number of samples in this frame.
    ///
    /// ```
    /// If frame truncation has occurred, this value will equal
    /// the (lesser) **truncatedSampleCount**. Otherwise, it will
    /// equal the sample count of the encapsulated AVFrame.
    /// ```
    ///
    /// # Note #
    ///
    /// See member **truncatedSampleCount** for an explanation of frame truncation.
    ///
    var sampleCount: Int32 {truncatedSampleCount ?? avFrame.nb_samples}
    
    ///
    /// The (lesser) number of samples to read, as a result of frame truncation. May be nil (if no truncation has occurred).
    /// For most samples, this value will be nil, i.e. most frames are not truncated.
    ///
    /// ```
    /// Frame truncation occurs when a frame has more samples
    /// than desired for scheduling or when seeking. So, only
    /// a subset of the frame's samples is actually used.
    ///
    /// Truncation can occur at either the beginning of the frame,
    /// via keepLastNSamples(), or at the end of the frame, via
    /// keepFirstNSamples().
    ///
    /// Example:
    ///
    /// Before truncation (has 1000 samples),
    /// sampleCount = 1000
    /// truncatedSampleCount = nil
    /// firstSampleIndex = 0
    ///
    /// Truncation at the beginning of the frame (keep the last 300 samples):
    /// keepLastNSamples(300)
    ///
    /// Result (Use only the last 300 samples of this frame, starting at index 700):
    /// sampleCount = 300
    /// truncatedSampleCount = 300
    /// firstSampleIndex = 700
    /// ```
    ///
    var truncatedSampleCount: Int32?
    
    ///
    /// Represents a starting offset to use when scheduling this frame's samples for playback.
    ///
    /// ```
    /// If frame truncation has occurred, i.e. through keepLastNSamples(),
    /// this value will represent the (non-zero) index of the first sample
    /// to be used. Otherwise, it will be 0.
    ///
    /// If truncation occurred at the end of the frame, i.e. when
    /// keepFirstNSamples() was called, this value will remain 0.
    /// ```
    ///
    /// # Note #
    ///
    /// See member **truncatedSampleCount** for an explanation of frame truncation.
    ///
    var firstSampleIndex: Int32
    
    ///
    /// Whether or not this frame has any samples.
    ///
    var hasSamples: Bool {avFrame.nb_samples.isPositive}
    
    ///
    /// Sample rate of the decoded data (i.e. number of samples per second or Hz).
    ///
    var sampleRate: Int32 {avFrame.sample_rate}
    
    ///
    /// For interleaved (packed) samples, this value will equal the size in bytes of data for all channels.
    /// For non-interleaved (planar) samples, this value will equal the size in bytes of data for a single channel.
    ///
    var lineSize: Int {Int(avFrame.linesize.0)}
    
    ///
    /// A timestamp indicating this frame's position (order) within the parent audio stream,
    /// specified in stream time base units.
    ///
    /// ```
    /// This can be useful when using concurrency to decode multiple
    /// packets simultaneously. The received frames, in that case,
    /// would be in arbitrary order, and this timestamp can be used
    /// to sort them in the proper presentation order.
    /// ```
    ///
    var timestamp: Int64 {avFrame.best_effort_timestamp}
    
    ///
    /// Presentation timestamp (PTS) of this frame, specified in the source stream's time base units.
    ///
    /// ```
    /// For packets containing a single frame, this frame timestamp will
    /// match that of the corrsponding packet.
    /// ```
    ///
    var pts: Int64 {avFrame.pts}
    
    ///
    /// Pointers to the raw data (unsigned bytes) constituting this frame's samples.
    ///
    var dataPointers: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>! {avFrame.extended_data}
    
    ///
    /// Instantiates a Frame, reading an AVFrame from the given codec context, and sets its sample format.
    ///
    /// - Parameter codecCtx: The codec context (i.e. decoder) from which to receive the new frame.
    ///
    /// - Parameter sampleFormat: The format of the samples in this frame.
    ///
    init?(readingFrom codecCtx: UnsafeMutablePointer<AVCodecContext>, withSampleFormat sampleFormat: FFmpegSampleFormat) {
        
        // Allocate memory for the frame.
        self.pointer = av_frame_alloc()
        
        // Check if memory allocation was successful. Can't proceed otherwise.
        guard pointer != nil else {
            
            print("\nFrame.init(): Unable to allocate memory for frame.")
            return nil
        }
        
        // Receive the frame from the codec context.
        guard avcodec_receive_frame(codecCtx, pointer).isNonNegative else {return nil}
        
        self.sampleFormat = sampleFormat
        self.firstSampleIndex = 0
    }
    
    ///
    /// Updates the frame's sample count to the given value, so that
    /// only the given number of samples, from the beginning of the frame,
    /// will be used when scheduling this frame for playback.
    ///
    /// - Parameter sampleCount: The new effective sample count.
    ///
    /// # Note #
    ///
    /// See member **truncatedSampleCount** for an explanation of frame truncation.
    ///
    func keepFirstNSamples(sampleCount: Int32) {
        
        if sampleCount < self.sampleCount {

            firstSampleIndex = 0
            truncatedSampleCount = sampleCount
        }
    }
    
    ///
    /// Updates the frame's sample count to the given value, and updates the starting sample
    /// offset (**firstSampleIndex**) accordingly, so that only the given number of samples,
    /// from the end of the frame, will be used when scheduling this frame for playback.
    ///
    /// - Parameter sampleCount: The new effective sample count.
    ///
    /// # Note #
    ///
    /// See member **truncatedSampleCount** for an explanation of frame truncation.
    ///
    func keepLastNSamples(sampleCount: Int32) {
        
        if sampleCount < self.sampleCount {

            firstSampleIndex = self.sampleCount - sampleCount
            truncatedSampleCount = sampleCount
        }
    }
    
    ///
    /// Copies this frame's samples to a given audio buffer starting at the given offset.
    ///
    /// - Parameter audioBuffer: The audio buffer to which this frame's samples are to be copied over.
    ///
    /// - Parameter offset:      A starting offset for each channel's data buffer in the audio buffer.
    ///                          This is required because the audio buffer may hold data from other
    ///                          frames copied to it previously. So, the offset will equal the sum of the
    ///                          the sample counts of all frames previously copied to the audio buffer.
    ///
    /// # Important #
    ///
    /// This function assumes that the format of the samples contained in this frame is: 32-bit floating-point planar,
    /// i.e. the samples do *not* require resampling.
    ///
    /// # Note #
    ///
    /// It is good from a safety perspective, to copy the frame's samples to the audio buffer right here rather than to give out a pointer to the memory
    /// space allocated from within this object so that a client object may perform the copy. This prevents any potentially unsafe use of the pointer.
    ///
    func copySamples(to audioBuffer: AVAudioPCMBuffer, startingAt offset: Int) {

        // Get pointers to the audio buffer's internal Float data buffers.
        guard let audioBufferChannels = audioBuffer.floatChannelData else {return}
        
        let intSampleCount: Int = Int(sampleCount)
        let intFirstSampleIndex: Int = Int(firstSampleIndex)
        
        for channelIndex in 0..<Int(channelCount) {
            
            // Get the pointers to the source and destination buffers for the copy operation.
            guard let bytesForChannel = dataPointers[channelIndex] else {break}
            let audioBufferChannel = audioBufferChannels[channelIndex]
            
            // Re-bind this frame's bytes to Float for the copy operation.
            bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount) {
                
                (floatsForChannel: UnsafeMutablePointer<Float>) in
                
                // Use Accelerate to perform the copy optimally, starting at the given offset.
                cblas_scopy(sampleCount, floatsForChannel.advanced(by: intFirstSampleIndex), 1, audioBufferChannel.advanced(by: offset), 1)
            }
        }
    }
    
    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false
    
    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized or is no longer needed.
    ///
    func destroy() {

        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}
        
        // Free up the space allocated to this frame.
        av_frame_unref(pointer)
        av_freep(pointer)
        
        destroyed = true
    }
    
    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}