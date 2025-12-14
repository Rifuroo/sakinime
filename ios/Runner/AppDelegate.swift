import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Setup Audio Session for background playback and PiP
        setupAudioSession()
        
        // Register plugins first
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup method channel for PiP communication
        setupMethodChannel()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session for video playback with background support
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured for PiP")
        } catch {
            print("❌ Failed to set audio session category: \(error.localizedDescription)")
        }
    }
    
    private func setupMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("❌ Failed to get FlutterViewController")
            return
        }
        
        methodChannel = FlutterMethodChannel(
            name: "com.sukinime/pip",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }
        
        print("✅ Method channel setup complete")
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isPiPSupported":
            handleIsPiPSupported(result: result)
            
        case "enterPiP":
            handleEnterPiP(result: result)
            
        case "enableAutoPiP":
            result(true)
            
        case "disableAutoPiP":
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleIsPiPSupported(result: @escaping FlutterResult) {
        // PiP is supported on iOS 14.0+
        if #available(iOS 14.0, *) {
            result(true)
            print("✅ PiP is supported on this device")
        } else {
            result(false)
            print("❌ PiP requires iOS 14.0 or later")
        }
    }
    
    private func handleEnterPiP(result: @escaping FlutterResult) {
        // On iOS, PiP is automatically handled by AVPlayerViewController
        // We just need to ensure the audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            result(true)
            print("✅ PiP mode activated")
        } catch {
            result(false)
            print("❌ Failed to activate PiP: \(error.localizedDescription)")
        }
    }
    
    // MARK: - App Lifecycle
    
    override func applicationWillResignActive(_ application: UIApplication) {
        // App is about to become inactive (entering background)
        // Notify Flutter that we might be entering PiP mode
        notifyPiPModeChanged(isInPiP: true)
        print("📱 App will resign active")
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        // App entered background - maintain audio session
        print("📱 App entered background")
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        // App is returning from background
        print("📱 App will enter foreground")
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        // App became active again
        // Notify Flutter that we're out of PiP mode
        notifyPiPModeChanged(isInPiP: false)
        print("📱 App became active")
    }
    
    // MARK: - Helper Methods
    
    private func notifyPiPModeChanged(isInPiP: Bool) {
        methodChannel?.invokeMethod(
            "onPiPModeChanged",
            arguments: ["isInPiP": isInPiP]
        )
        print("📡 Notified Flutter: PiP mode = \(isInPiP)")
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Cleanup audio session when app terminates
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}