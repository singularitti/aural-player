import Foundation

///
/// Encapsulates an ffmpeg AVFormatContext struct that represents an audio file's container format,
/// and provides convenient Swift-style access to its functions and member variables.
///
/// - Demultiplexing: Reads all streams within the audio file.
/// - Reads and provides audio stream data as encoded / compressed packets (which can be passed to the appropriate codec).
/// - Performs seeking to arbitrary positions within the audio stream.
///
class FFmpegFormatContext {

    ///
    /// The file that is to be read by this context.
    ///
    let file: URL
    
    ///
    /// The absolute path of **file***, as a String.
    ///
    let filePath: String
    
    ///
    /// The encapsulated AVFormatContext object.
    ///
    var avContext: AVFormatContext {pointer.pointee}
    
    ///
    /// A pointer to the encapsulated AVFormatContext object.
    ///
    var pointer: UnsafeMutablePointer<AVFormatContext>!
    
    ///
    /// An array of all audio / video streams demuxed by this context.
    ///
    let streams: [FFmpegStreamProtocol]
    
    ///
    /// The number of streams present in the **streams** array.
    ///
    let streamCount: Int
    
    ///
    /// The first / best audio stream in this file, if one is present. May be nil.
    ///
    let audioStream: FFmpegAudioStream?
    
    ///
    /// The first / best video stream in this file, if one is present. May be nil.
    ///
    /// # Notes #
    ///
    /// While, in general, a video stream may contain a large number of packets,
    /// for our purposes, a video stream is treated as an "image" (i.e still image) stream
    /// with only one packet - containing our cover art.
    ///
    let imageStream: FFmpegImageStream?
    
    ///
    /// Whether or not this file is a raw audio file. This simply means that
    /// the file has not been muxed into a container and therefore does not
    /// contain accurate duration information.
    ///
    /// e.g. dts, aac, ac3.
    ///
    /// ```
    /// This is determined by simply checking the file's
    /// extension.
    /// ```
    ///
    let isRawAudioFile: Bool
    
    ///
    /// Duration of the audio stream in this file, in seconds.
    ///
    /// ```
    /// This is determined using various methods (strictly in the following order of precedence):
    ///
    /// For raw audio files,
    ///
    ///     A packet table is constructed, which computes the duration by brute force (reading all
    ///     of the stream's packets and using their presentation timestamps).
    ///
    /// For files in containers,
    ///
    ///     - If the stream itself has valid duration information, that is used.
    ///     - Otherwise, if avContext has valid duration information, it is used to estimate the duration.
    ///     - Failing the above 2 methods, the duration is defaulted to a 0 value (indicating an unknown value)
    /// ```
    ///
    var duration: Double = 0

    ///
    /// A duration estimated from **avContext**, if it has valid duration information. Nil otherwise.
    /// Specified in seconds.
    ///
    private lazy var estimatedDuration: Double? = avContext.duration > 0 ? (Double(avContext.duration) / Double(AV_TIME_BASE)) : nil
    
    ///
    /// A duration computed with brute force, by building a packet table.
    /// Specified in seconds.
    ///
    /// # Notes #
    ///
    /// This is an expensive and potentially lengthy computation.
    ///
    private lazy var bruteForceDuration: Double? = packetTable?.duration
    
    ///
    /// A packet table that contains position and timestamp information
    /// for every single packet in the audio stream.
    ///
    /// It provides 2 important properties:
    ///
    /// 1 - Duration of the audio stream
    /// 2 - The byte position and presentation timestamp of each packet,
    /// which allows efficient arbitrary seeking.
    ///
    /// # Notes #
    ///
    /// Will be nil if an error occurs while opening the file and/or reading its packets.
    ///
    /// This is an expensive and potentially lengthy computation.
    ///
    private lazy var packetTable: FFmpegPacketTable? = FFmpegPacketTable(forFile: file)
    
    ///
    /// Bit rate of the audio stream, 0 if not available.
    /// May be computed if not directly known.
    ///
    var bitRate: Int64
    
    ///
    /// Size of this file, in bytes.
    ///
    lazy var fileSize: UInt64 = {
        
        do {
            
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
            return fileAttributes[FileAttributeKey.size] as? UInt64 ?? 0
            
        } catch let error as NSError {
            
            NSLog("Error getting size of file '%@': %@", filePath, error.description)
            return 0
        }
    }()
    
    ///
    /// All metadata key / value pairs available in this file's header.
    ///
    lazy var metadata: [String: String] = FFmpegMetadataDictionary(readingFrom: avContext.metadata).dictionary
    
    ///
    /// All chapter markings available in this file's header.
    ///
    lazy var chapters: [FFmpegChapter] = {
        
        let numChapters = Int(avContext.nb_chapters)
        
        // There may not be any chapters.
        guard numChapters > 0, let avChapters = avContext.chapters else {return []}
        
        // Sort the chapters by start time in ascending order.
        let theChapters: [AVChapter] = (0..<numChapters).compactMap {avChapters.advanced(by: $0).pointee?.pointee}
            .sorted(by: {c1, c2 in c1.start < c2.start})
        
        // Wrap the AVChapter objects in Chapter objects.
        return theChapters.enumerated().map {FFmpegChapter(encapsulating: $0.element, atIndex: $0.offset)}
    }()
    
    ///
    /// The number of chapters present in the **chapters** array.
    ///
    lazy var chapterCount: Int = chapters.count
    
    ///
    /// Attempts to construct a FormatContext instance for the given file.
    ///
    /// - Parameter file: The audio file to be read / decoded by this context.
    ///
    /// Fails (returns nil) if:
    ///
    /// - An error occurs while opening the file or reading (demuxing) its streams.
    /// - No audio stream is found in the file.
    ///
    init(forFile file: URL) throws {
        
        self.file = file
        self.filePath = file.path
        
        // MARK: Open the file ----------------------------------------------------------------------------------
        
        // Allocate memory for this format context.
        self.pointer = avformat_alloc_context()
        
        guard self.pointer != nil else {
            throw FormatContextInitializationError(description: "Unable to allocate memory for format context for file '\(filePath)'.")
        }
        
        // Try to open the audio file so that it can be read.
        var resultCode: ResultCode = avformat_open_input(&pointer, file.path, nil, nil)
        
        // If the file open failed, log a message and return nil.
        guard resultCode.isNonNegative, pointer?.pointee != nil else {
            throw FormatContextInitializationError(description: "Unable to open file '\(filePath)'. Error: \(resultCode.errorDescription)")
        }
        
        // MARK: Read the streams ----------------------------------------------------------------------------------
        
        // Try to read information about the streams contained in this file.
        resultCode = avformat_find_stream_info(pointer, nil)
        
        // If the read failed, log a message and return nil.
        guard resultCode.isNonNegative else {
            throw FormatContextInitializationError(description: "Unable to find stream info for file '\(filePath)'. Error: \(resultCode.errorDescription)")
        }
        
        var streams: [FFmpegStreamProtocol] = []
        
        // Iterate through all the streams, and store all the ones we care about (i.e. audio / video) in the streams array.
        
        if let avStreams = pointer?.pointee.streams {
        
            let avStreamPointers: [UnsafeMutablePointer<AVStream>] = (0..<pointer.pointee.nb_streams).compactMap {avStreams.advanced(by: Int($0)).pointee}
            
            streams = try avStreamPointers.compactMap {streamPointer in
                
                switch streamPointer.pointee.codecpar.pointee.codec_type {
                    
                // For audio / video streams, wrap the AVStream in a AudioStream / ImageStream.
                    
                case AVMEDIA_TYPE_AUDIO:    return try FFmpegAudioStream(encapsulating: streamPointer)
                    
                case AVMEDIA_TYPE_VIDEO:    return try FFmpegImageStream(encapsulating: streamPointer)
                    
                default:                    return nil
                    
                }
            }
        }
        
        self.streams = streams
        self.streamCount = streams.count
        
        // Among all the discovered streams, find the first / best audio stream and/or video stream.
        // TODO: Should we use av_find_best_stream() here instead of picking the first audio stream ???
        
        self.audioStream = streams.compactMap({$0 as? FFmpegAudioStream}).first
        self.imageStream = streams.compactMap({$0 as? FFmpegImageStream}).first
        
        // Compute the duration of the audio stream, trying various methods. See documentation of **duration**
        // for a detailed description.
        self.isRawAudioFile = AppConstants.SupportedTypes.rawAudioFileExtensions.contains(file.pathExtension.lowercased())
        self.bitRate = pointer.pointee.bit_rate
        
        self.duration = (isRawAudioFile ? bruteForceDuration : audioStream?.duration ?? estimatedDuration) ?? 0
        if self.bitRate == 0 {self.bitRate = duration == 0 ? 0 : Int64(round(Double(fileSize) / duration))}
    }
    
    ///
    /// Read and return a single packet from this context, that is part of a given stream.
    ///
    /// - Parameter stream: The stream we want to read from.
    ///
    /// - returns: A single packet, if its stream index matches that of the given stream, nil otherwise.
    ///
    /// - throws: **PacketReadError**, if an error occurred while attempting to read a packet.
    ///
    func readPacket(from stream: FFmpegStreamProtocol) throws -> FFmpegPacket? {
        
        let packet = try FFmpegPacket(readingFromFormat: pointer)
        return packet.streamIndex == stream.index ? packet : nil
    }
    
    ///
    /// Seek to a given position within a given stream.
    ///
    /// - Parameter stream:     The stream within which we want to perform the seek.
    /// - Parameter time:       The target seek position within the stream, specified in seconds.
    ///
    /// - throws: **PacketReadError**, if an error occurred while attempting to read a packet.
    ///
    func seek(within stream: FFmpegAudioStream, to time: Double) throws {
        
        // Before attempting the seek, it is necessary to ask the codec
        // to flush its internal buffers. Otherwise, stale frames may
        // be produced when decoding.
//        stream.codec.flushBuffers()
        
        // Represents the target seek position that the format context understands.
        var timestamp: Int64 = 0
        
        // Describes the seeking mode to use (seek by frame, seek by byte, etc)
        var flags: Int32 = 0
        
        if isRawAudioFile {
            
            // For raw audio files, we must use the packet table to determine
            // the byte position of our target packet, given the seek position
            // in seconds.
            timestamp = packetTable?.closestPacketBytePosition(for: time) ?? 0
            
            // Validate the byte position (cannot be greater than the file size).
            if timestamp >= fileSize {throw SeekError(ERROR_EOF)}
            
            // We need to seek by byte position.
            flags = AVSEEK_FLAG_BYTE
            
        } else {
            
            // Validate the duration of the file (which is needed to compute the target frame).
            if duration <= 0 {throw SeekError(-1)}
            
            // We need to determine a target frame, given the seek position in seconds,
            // duration, and frame count.
            timestamp = Int64(time * Double(stream.timeBaseDuration) / duration)
            
            // Validate the target frame (cannot exceed the total frame count)
            if timestamp >= stream.timeBaseDuration {throw SeekError(ERROR_EOF)}
            
            // We need to seek by frame.
            //
            // NOTE - AVSEEK_FLAG_BACKWARD "indicates that you want to find closest keyframe
            // having a smaller timestamp than the one you are seeking."
            //
            // Source - https://stackoverflow.com/questions/20734814/ffmpeg-av-seek-frame-with-avseek-flag-any-causes-grey-screen
            flags = AVSEEK_FLAG_BACKWARD
        }
        
        // Attempt the seek and capture the result code.
        let seekResult: ResultCode = av_seek_frame(pointer, stream.index, timestamp, flags)
        
        // If the seek failed, log a message and throw an error.
        guard seekResult.isNonNegative else {

            print("\nFormatContext.seek(): Unable to seek within stream \(stream.index). Error: \(seekResult) (\(seekResult.errorDescription)))")
            throw SeekError(seekResult)
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

        // Close the context.
        avformat_close_input(&pointer)
        
        // Free the context and all its streams.
        avformat_free_context(pointer)
        
        destroyed = true
    }

    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}
