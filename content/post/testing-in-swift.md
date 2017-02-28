---
authors:
- ybai
- dcarter
categories:
- Swift
- Swift 3
- Protocol
- Testing
date: 2017-02-28T10:55:42-05:00
draft: true
short: |
  Testing against frameworks/libraries is tricky in Swift because we can't just spy on dependencies and fake out the response. Here is how we test neatly in Swift 3.
title: Testing in Swift with dependencies out of control
---
## Background
{{< responsive-figure src="/images/testing-in-swift/icon.png" class="right" >}}
Pivots have work photos mixed in with their personal photos on their phone and
sometimes never get deleted. So we built an iOS app in Swift 3 to help Pivots
remove client photos on their phone.


---
## Unit Tests

### Dependency Injection

With [dependency injection](https://en.wikipedia.org/wiki/Inversion_of_control), the depending modules are initiated outside of our testing subject. Our testing subject can use the injected modules according to methods defined through abstraction (protocol in Swift, interface in Java). This is essential for unit testing because we can initiate our testing subject with fake modules, which also conform the same abstraction, in tests.


```Swift
import Swinject

class ContainerFactory {

    let container = Container() { c in
        c.register(PhotosViewController.self) { r in
            return PhotosViewController(withGoogleService: r.resolve(GoogleServiceProtocol.self)!)
        }
        c.register(GoogleServiceProtocol.self) { r in
            return GoogleService(withSignIn: GIDSignIn.sharedInstance(), withDrive: GTLRDriveService())
        } to
    }
}
```

```Swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    let containerFactory = ContainerFactory()
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let appContainer = containerFactory.container

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window!.rootViewController = appContainer.resolve(PhotosViewController.self)!

        return true
    }
}
```

### Faking with Protocol

```Swift
protocol GoogleServiceProtocol {
    func uploadPhotos(forImages: [Data]?, completion: (() -> ())?)
}
```


#### Synchronous calls
```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var uploadCalled = false

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.uploadCalled = true
    }
}
```
#### Asynchronous calls
```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var completion: (() -> ())?

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.completion = completion
    }
}
```
#### Deferring the callback
```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var shouldCallPostSignIn = true

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        if shouldCallPostSignIn {
            completion?()  
        }
    }
}
```
#### Signature wrapping
**Case 1 - UIViewController**
```Swift
protocol UIViewControllerProtocol {
    func presentOn(_ view: UIViewController, animated: Bool, completion: (() -> ())?)
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

extension UIViewController: UIViewControllerProtocol {
    func presentOn(_ view: UIViewController, withMessage message: String, animated: Bool, completion: (() -> ())?) {
        view.present(self as UIViewController, animated: animated, completion: {
            completion?()
        })
    }
}
```

```Swift
class FakeActivityOverlayViewController: ActivityOverlayViewControllerProtocol {

    var isPresented = false

    func presentOn(_ view: UIViewController, withMessage message: String, animated: Bool, completion: (() -> ())?) {
        isPresented = true
        completion?()
    }

    func dismiss(animated: Bool, completion: (() -> ())?) {
        isPresented = false
        completion?()
    }
}

```
**Case 2 - when existing signature is hard to fake out**
```Swift
protocol GTLRDriveServiceProtocol {
    func execute(query: GTLRQueryProtocol, completionHandler handler: ((GTLRServiceTicket?, Any?, Error?) -> Void)?) -> GTLRServiceTicket?
}

extension GTLRDriveService: GTLRDriveServiceProtocol {
    func execute(query: GTLRQueryProtocol, completionHandler handler: ((GTLRServiceTicket?, Any?, Error?) -> Void)?) -> GTLRServiceTicket? {
        return self.executeQuery(query) { (ticket, any, error) in
            handler?(ticket, any, error)
        }
    }
}
```

---
## UI Tests
### Setup device
```Swift
class SimulatorSetupViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
            self.cleanUpCameraRoll {
                self.addPhotosToCameraRoll()
            }
        }
    }

    func cleanUpCameraRoll(_ completion: @escaping () -> ()) {
        PHPhotoLibrary.shared().performChanges({
            let assets = PHAsset.fetchAssets(with: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { success, error in
            completion()
        })
    }

    func addPhotosToCameraRoll() {
        try? PHPhotoLibrary.shared().performChangesAndWait {
            self.generateAssetCreationRequest(atLocation: self.pivotalLocation, onDate: self.date3)
            self.generateAssetCreationRequest(atLocation: self.pivotalLocation, onDate: self.date2)
            self.generateAssetCreationRequest(atLocation: self.nonPivotalLocation, onDate: self.date4)

            for _ in (1...8) {
                self.generateAssetCreationRequest(atLocation: self.pivotalLocation, onDate: self.date1)
            }
        }
    }
}
```


### System dialog
```Swift
class simulatorPhotoLibrarySetupUITests: XCTestCase {

    var app:XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "alert handler") { alert -> Bool in
            if (alert.buttons["OK"].exists) {
                alert.buttons["OK"].tap()
                RunLoop.current.run(until: Date(timeInterval: 5, since: Date()))
            }
            else if (alert.buttons["Delete"].exists) {
                alert.buttons["Delete"].tap()
            }
            else {
                XCTFail("We don't know what's going on!?")
            }

            return true
        }
    }

    func testDoesNothingJustWaitForSetupToFinish() {
        RunLoop.current.run(until: Date(timeInterval: 5, since: Date()))
        app.tap()
    }

}
```
