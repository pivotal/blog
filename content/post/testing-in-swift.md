---
authors:
- ybai
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
Pivots often have work photos mixed in with their personal photos on their phone
and never get deleted. So we built an iOS app in Swift 3 to help Pivots to deal
with client photos from their phone. By the nature of the app, we need to talk
to native [iOS Photos library](https://developer.apple.com/reference/photos), integrate with Google Drive, and some other share option views. Testing our code without worrying
about external libraries becomes crucial to us.

We had quite a journey figuring out our testing strategies against those depending
libraries both in unit tests and in UI tests. And now when we look back, we would
love to tell use 3 months ago to follow the following suggestions:

* Inject the dependencies with protocols and use fakes in tests
* If something is hard to test, don't try too hard, abstract it out instead
* If you are digging too deep into the depending library source code, then you are doing it wrong

We are going to explain more about our testing strategies below. We are using [UIViewController](https://developer.apple.com/reference/uikit/uiviewcontroller) as example of native libraries that we can't change for testing and Google services([Signin](https://developers.google.com/identity/sign-in/ios/start-integrating) and [Drive](https://developers.google.com/drive/v3/web/quickstart/ios?ver=swift)) as example of external dependencies testing.

---
## Unit Tests

In our app, PhotosViewController is the rootViewController that we are mainly testing, and we uses dozens of depending services and views to process detailed tasks to isolate responsibilities.

### **Dependency Injection**

With [dependency injection](https://en.wikipedia.org/wiki/Inversion_of_control), the depending modules are initiated outside of our testing subject. Our testing subject can use the injected modules according to methods defined through abstraction ([protocol](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/Protocols.html) in Swift, [interface](https://docs.oracle.com/javase/tutorial/java/concepts/interface.html) in Java). This is essential for unit testing because we can initiate our testing subject with fake modules, which also conform the same abstraction, in tests.

Here is the example of using [Swinject](https://github.com/Swinject/Swinject) to inject dependencies in our iOS app:

```Swift
import Swinject

class ContainerFactory {

    let container = Container() { c in
        c.register(PhotosViewController.self) { r in
            return PhotosViewController(withGoogleService: r.resolve(GoogleServiceProtocol.self)!)
        }
        c.register(GoogleServiceProtocol.self) { r in
            return GoogleService(withSignIn: GIDSignIn.sharedInstance(), withDrive: GTLRDriveService())
        }
        // And more other dependencies
    }
}
```

We registered each abstracted type with actual implementation instance, so that we can resolve it whenever needed. And when we initiate our PhotosViewController,  we inject a GoogleService instance that conforms GoogleServiceProtocol.

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

### **Faking with Protocol**

You might have noticed that we are using protocols when we declare dependencies and instantiate our PhotosViewController with implementations. Here is the use case:

**Goal**: Upload photos to Google Drive.

**Tasks**: Sign in with Google and cooperate with the Drive API.

**Solution**: We defined the following GoogleServiceProtocol with a function to upload photos with given images, and extracted all the Google related operation in GoogleService.

**Test**: We created FakeGoogleService class to conform GoogleServiceProtocol and initialize our testing target with the fake instances.

**Celebrate!** Our main controller only need to call uploadPhotos and doesn't need to worry about checking authorization status, how to assemble requests to actually upload photos, or knowing when the requests are finished.

```Swift
protocol GoogleServiceProtocol {
    func uploadPhotos(forImages: [Data]?, completion: (() -> ())?)
}
```

**Now, how to verify in tests?**

#### 1. *Synchronous calls*

We just need to verify our photosViewController has called uploadPhotos because we trust the service, so we can simply add a boolean property in our fake service and update it when the function is called, or one step further to store the parameters and verify them in the tests.

```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var uploadPhotosCalled = false
    // var photosToUpload : [Data]?

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.uploadPhotosCalled = true
        // self.photosToUpload = images
        completion?()
    }
}
```

#### 2. *Asynchronous calls*

What if we want to verify some behavior before the async call finishes? For example an "Uploading..." indicator that goes away after finishes.

Here is what we do: *store the callback method* -> *verified the indicator is presented* -> *call the stored callback* -> *verify the indicator is gone*.

```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var completion: (() -> ())?
    var shouldCallCompletion = true

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.completion = completion
        if shouldCallCompletion {
            completion?()  
        }
    }
}
```

### **Signature wrapping with extension**
#### *Case 1 - UIViewController*

```Swift
protocol UIViewControllerProtocol {
    func presentOn(_ view: UIViewController, withMessage: String, animated: Bool, completion: (() -> ())?)
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
#### *Case 2 - when existing signature is hard to fake out*
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
{{< responsive-figure src="/images/testing-in-swift/cat.jpg" class="right" >}}
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

```
asdfjsdhfkjhsklfkl
```Swift
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
