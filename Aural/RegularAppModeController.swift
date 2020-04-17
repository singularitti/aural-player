import Cocoa

class RegularAppModeController: AppModeController {
    
    var mode: AppMode {return .regular}
    private lazy var windowManager: WindowManagerProtocol = ObjectGraph.windowManager
    private var constituentViews: [ConstituentView] = []
    
    func presentMode() {
        NSApp.setActivationPolicy(.regular)
        windowManager.initialLayout()
        constituentViews.forEach({$0.activate()})
    }
    
    func dismissMode() {
//        windowManager.closeWindows()
        constituentViews.forEach({$0.deactivate()})
    }
    
    func registerConstituentView(_ view: ConstituentView) {
        constituentViews.append(view)
    }
}
