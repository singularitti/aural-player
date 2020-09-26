import Cocoa
import AVFoundation

/*
    Encapsulates low-level logic required to interact with the system's audio output hardware
 
    Serves as a helper class to AudioGraph to get/set the current audio output device
 */
public class DeviceManager {
    
    private let systemAudioObjectId: AudioObjectID = .systemAudioObject
    
    // The AudioUnit underlying AVAudioEngine's output node (used to set the output device)
    var outputAudioUnit: AudioUnit
    
    let list: DeviceList
    
    init(outputAudioUnit: AudioUnit, preferredDeviceUID: String?) {
        
        self.outputAudioUnit = outputAudioUnit
        self.list = DeviceList()
        
        if let thePreferredDeviceUID = preferredDeviceUID,
            let foundDevice = list.deviceByUID(thePreferredDeviceUID) {
            
            // Try to remember the preferred output device
            outputDeviceId = foundDevice.id
            
        } else {    // Default to the system device
            
            outputDeviceId = systemDeviceId
        }
    }
    
    // A listing of all available audio output devices
    var allDevices: AudioDeviceList {
        AudioDeviceList(allDevices: list.devices, outputDeviceId: outputDeviceId, systemDeviceId: systemDeviceId)
    }
    
    var systemDevice: AudioDevice {
        list.deviceById(systemDeviceId) ?? AudioDevice(deviceId: systemDeviceId)!
    }
    
    // The AudioDeviceID of the audio output device currently being used by the OS
    private var systemDeviceId: AudioDeviceID {systemAudioObjectId.defaultOutputDevice}
    
    var outputDevice: AudioDevice {
        
        get {list.deviceById(outputDeviceId) ?? AudioDevice(deviceId: outputDeviceId) ?? systemDevice}
        set {outputDeviceId = newValue.id}
    }
    
    // The variable used to get/set the application's audio output device
    private var outputDeviceId: AudioDeviceID {
        
        get {outputAudioUnit.currentDevice}
        
        set(newDeviceId) {
            
            // TODO: Validate that the device still exists ? By doing a lookup in list.map ???
            
            if outputDeviceId != newDeviceId {
                outputAudioUnit.currentDevice = newDeviceId
            }
        }
    }
}

extension Notification.Name {
    
    // ----------------------------------------------------------------------------------------
    
    // MARK: Notifications published by the application (i.e. app delegate). They represent different lifecycle stages/events.
    
    // Signifies that the list of audio output devices has been updated.
    static let deviceManager_deviceListUpdated = Notification.Name("deviceManager_deviceListUpdated")
}
