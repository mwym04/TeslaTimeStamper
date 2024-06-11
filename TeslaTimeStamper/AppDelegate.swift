
import UIKit
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.myapp.videoexport", using: nil) { task in
            self.handleVideoExport(task: task as! BGProcessingTask)
        }
        return true
    }

    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.example.myapp.videoexport")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }

    func handleVideoExport(task: BGProcessingTask) {
        task.expirationHandler = {
            // 작업이 시간 내에 완료되지 않을 경우 정리 작업
        }

        Task {
            let videoExporter = VideoExporter()
            guard let selectedVideoURL = ContentView.shared.selectedVideoURL,
                  let creationDate = ContentView.shared.creationDate else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                let exportURL = try await videoExporter.export(url: selectedVideoURL, creationDate: creationDate)
                await videoExporter.saveToLibrary(url: exportURL!)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
                print("Failed to export video: \(error.localizedDescription)")
            }
        }
    }
}
