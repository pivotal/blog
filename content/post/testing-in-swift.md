---
authors:
- ybai
- dancarter
categories:
- Swift
- Swift 3
- Protocol
- Testing
date: 2017-03-31T10:55:42-05:00
short: |
  Testing against frameworks/libraries is tricky in Swift because we can't just spy on dependencies and fake out the response. Here is how we test neatly in Swift 3.
title: Testing in Swift with Dependencies
---
## Background
It is common for pivots to find their phones cluttered with work photos that never get deleted. To address this problem, we built an iOS app in Swift 3 to help pivots quickly find and take action on their work photos. By the nature of the app, we found ourselves working with the native [iOS `Photos` library](https://developer.apple.com/reference/photos), integrating with Google Drive, and working with various views for sharing photos. The ability to easily test our code while working around various integrations was crucial for our project.

{{< responsive-figure src="/images/testing-in-swift/icon.png" class="right" >}}

It was quite a journey for us to find maintainable testing strategies for our code that dealt with these external dependencies. Looking back, there are three main points we would love to be able to share with ourselves three months ago:

* Inject all dependencies with protocols and use fakes in tests
* If something is hard to test, don't spend too much time on it, abstract it out instead
* If you are digging too deeply into the dependent library's source code, then you may be doing it wrong

To illustrate the testing strategies we landed upon, we will use [`UIViewController`](https://developer.apple.com/reference/uikit/uiviewcontroller) as an example of a native library dependency, and Google services([Signin](https://developers.google.com/identity/sign-in/ios/start-integrating) and [Drive](https://developers.google.com/drive/v3/web/quickstart/ios?ver=swift)) as examples of external dependencies.

---
## Unit Tests

The `PhotosViewController` is the `rootViewController` of our app and our main target for unit testing. It relies on over a dozen other views and services to complete tasks and isolate responsibilities.

### **Dependency Injection**

With [dependency injection](https://en.wikipedia.org/wiki/Inversion_of_control), external code that a test subject relies on is instantiated externally and passed into the subject. This way, the code we are testing can use methods defined through abstraction ([protocol](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/Protocols.html) in Swift, similar to an [interface](https://docs.oracle.com/javase/tutorial/java/concepts/interface.html) in Java) on the injected dependencies. This is essential for unit testing because we can initiate our test subject with fake modules allowing us to test just the subject and not its dependencies.

### **Faking with Protocols**

We use protocols for all of the dependencies our `PhotosViewController` relies on and pass in implementations. Here is an example use case:

**Goal**: Upload photos to Google Drive.

**Tasks**: Sign in with Google and talk to the Drive API.

**Solution**: We defined a `GoogleServiceProtocol` with a method signature for uploading photos with given images, and extracted all the Google related operations into `GoogleService`, an implementation of the protocol.

**Test**: We created `FakeGoogleService` class that conforms to the `GoogleServiceProtocol` and initialize our test target with the fake.

**Celebrate!** Our main controller only needs to call `uploadPhotos` on the injected dependency and doesn't need to worry about checking authorization status, assembling requests to upload photos, or knowing when the requests are finished.

```Swift
protocol GoogleServiceProtocol {
    func uploadPhotos(forImages: [Data]?, completion: (() -> ())?)
}
```

**How to verify calls in tests?**

#### 1. *Synchronous calls*

We just need to verify our `PhotosViewController` has called `uploadPhotos` because we trust the service, so we can simply add a boolean property in our fake service and update it when the function is called, or go a step further and store the parameters and verify them in the tests.

```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var uploadPhotosCalled = false
    // var imagesToUpload : [Data]?

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.uploadPhotosCalled = true
        // self.imagesToUpload = imagesToUpload
        completion?()
    }
}
```

#### 2. *Asynchronous calls*

What if we want to verify some behavior before an async call finishes? For example an "Uploading..." indicator that goes away after the upload finishes.

Here is what we do: *store the callback method* -> *verify the indicator is presented* -> *call the stored callback* -> *verify the indicator is gone*.

```Swift
class FakeGoogleService: GoogleServiceProtocol {

    var completion: (() -> ())?

    func uploadPhotos(forImages images: [Data]?, completion: (() -> ())?) {
        self.completion = completion
    }
}
```

### **Signature wrapping with extensions**
#### *Case 1 - Check if an overlay view is presented*
We have an overlay view that presents on top of our `PhotosViewController` when we are waiting for the `GoogleService` to finish uploading.

Originally, we accomplished this by calling the present method on the test target itself:

```Swift
//PhotosViewController.Swift
self.present(activityOverlayViewController as UIViewController, animated: false) {
    googleService.uploadPhotos(forImages: images) {
        activityOverlayViewController.dismiss(animated: false, completion: maybeDoSomethingElse)
    }
}
```

We struggled for a long time trying to find a way to test it properly, but we failed for the following reasons:

1. Dismissing the overlay doesn't work well for standalone view controller tests.
2. It's tedious and hard to mimic the async callback chain.

After a Ping Pong break, we came up with the idea to let the overlay view present itself:

```Swift
protocol UIViewControllerProtocol {
    func presentOn(_ view: UIViewController, withMessage: String, animated: Bool, completion: (() -> ())?)
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

extension UIViewController: UIViewControllerProtocol {
    func presentOn(_ view: UIViewController, withMessage message: String, animated: Bool,
      completion: (() -> ())?) {
        view.present(self as UIViewController, animated: animated, completion: {
            completion?()
        })
    }
}
```

By extending `UIViewController` to conform to `UIViewControllerProtocol` with the new signature, we avoid spinning up a real view on top of the view we are testing, and are able to write better tests.

```Swift
class FakeActivityOverlayViewController: UIViewControllerProtocol {

    var isPresented = false

    func presentOn(_ view: UIViewController, withMessage message: String, animated: Bool,
      completion: (() -> ())?) {
        isPresented = true
        completion?()
    }

    func dismiss(animated: Bool, completion: (() -> ())?) {
        isPresented = false
        completion?()
    }
}

```
#### *Case 2 - An existing signature is hard to fake out*
Sometimes, it is hard to fake out a method due to strong constraints of the original method signature. For example:

```Swift
func execute(query: GTLRQueryProtocol, completionHandler handler: ((GTLRServiceTicket, Any, Error) -> Void)) -> GTLRServiceTicket
```

The function above requires a `GTLRServiceTicket` instance as the return type, a class which doesn't have a default simple initializer. After digging into the `GTLRDriveService` source code for a while, we realized that we have to know too much about this external library.

To counter this issue, we loosen the constraint of the signature in a protocol by making the return value optional, and extend the real service to implement the new signature and call the real function internally.

```Swift
protocol GTLRDriveServiceProtocol {
    func execute(query: GTLRQueryProtocol, completionHandler handler:
      ((GTLRServiceTicket?, Any?, Error?) -> Void)?) -> GTLRServiceTicket?
}

extension GTLRDriveService: GTLRDriveServiceProtocol {
    func execute(query: GTLRQueryProtocol, completionHandler handler:
      ((GTLRServiceTicket?, Any?, Error?) -> Void)?) -> GTLRServiceTicket? {
        return self.executeQuery(query) { (ticket, any, error) in
            handler?(ticket, any, error)
        }
    }
}
```

---
## UI Tests

### **Dependency Injection**
Dealing with dependency injection in UI tests isn't quite as simple as unit tests. To help simplify injecting real objects when the app is running versus fake objects when UI tests are running, we utilized [Swinject](https://github.com/Swinject/Swinject). Here is an example of injecting dependencies with Swinject:

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
        // And other dependencies
    }
}
```

We register each abstracted type with an actual implementation instance so that we can resolve it when needed. When we initiate our `PhotosViewController`, we inject a `GoogleService` instance that conforms to `GoogleServiceProtocol`.

For our UI tests, we have a second container that overrides the registered protocols for services we want to fake. Then, our `ContainerFactory` can provide a method that supplies the correct container based on whether the app or UI tests are running:
```Swift
class ContainerFactory {
  ...

  var uiTestContainer: Container {
    get {
        container.register(GoogleServiceProtocol.self) { r in
            return FakeGoogleService(withSignIn: GIDSignIn.sharedInstance(), withDrive: GTLRDriveService())
        }

        return container
    }
  }

  func getContainer() -> Container {
      if ProcessInfo.processInfo.arguments.contains("-UITesting") {
          return uiTestContainer
      }

      return container
  }
}
```

In our `AppDelegate`, we use the `ContainerFactory` to retrieve the appropriate container to resolve our dependencies:

```Swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    let containerFactory = ContainerFactory()
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:
      [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let appContainer = containerFactory.container

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window!.rootViewController = appContainer.resolve(PhotosViewController.self)!

        return true
    }
}
```

In the `setUp` method for our UI tests, we add the `"-UITesting"` flag to our `launchArguments`:
```Swift
// workPhotosUITests.swift
  override func setUp() {
    super.setUp()

    // Setup code

    app = XCUIApplication()
    app.launchArguments.append("-UITesting")
    app.launch()
    app.tap()
  }
```

### **Responding to system dialogs**

Since our app will be accessing the camera roll and deleting photos, iOS will prompt the user to grant our app permission to perform these actions. Here is an example for dealing with system dialogs:

```Swift
class workPhotosUITests: XCTestCase {

    var app:XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()

        // Have this ready before system dialogs pop up
        addUIInterruptionMonitor(withDescription: "alert handler") { alert -> Bool in
            // Different dialogs may have different confirm buttons
            if (alert.buttons["OK"].exists) {
                alert.buttons["OK"].tap()
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

    func testThatTriggersASystemDialog() {
        // Some code the triggers a system dialog here...

        // System dialogs are in a different thread, so give them some time to sync up
        RunLoop.current.run(until: Date(timeInterval: 2, since: Date()))
        // Refocus on the app to dismiss dialog
        app.tap()
    }

}
```

### **A separate app to setup the device**

To test that our app can really load images from the iPhone's camera roll and respond to user interaction correctly, we need to setup the device to have images with the desired metadata to test against.

Interacting with the camera roll requires utilizing the iOS `Photos` library, which can't be done within our UI tests. To avoid putting our UI test setup within our production code, we decided to have a separate app to handle all the setup and fill the camera roll with this cute cat picture:

{{< responsive-figure src="/images/testing-in-swift/cat.jpg" class="center" >}}

The `rootViewController` for this app will clear out existing photos and add the ones our UI tests are expecting. This will allow us to have a consistent starting state when our UI tests are run.
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

    private func cleanUpCameraRoll(_ completion: @escaping () -> ()) {
        PHPhotoLibrary.shared().performChanges({
            let assets = PHAsset.fetchAssets(with: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { success, error in
            completion()
        })
    }

    private func addPhotosToCameraRoll() {
        try? PHPhotoLibrary.shared().performChangesAndWait {
            self.generateAssetCreationRequest(atLocation: self.nonPivotalLocation, onDate: self.date2)

            for _ in (1...8) {
                self.generateAssetCreationRequest(atLocation: self.pivotalLocation, onDate: self.date1)
            }
        }
    }
}
```
To make sure this code is executed when we run our tests, we added a simple UI test for this app that will cause the setup code to run.
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

    func testTriggerControllerCode() {
        RunLoop.current.run(until: Date(timeInterval: 5, since: Date()))
        app.tap()
    }
}
```
Now that this setup is required before our UI tests, we have to make sure it runs first. We can set up our scheme to make sure the setup app's tests will run first:

{{< responsive-figure src="/images/testing-in-swift/test-scheme.png" class="center" >}}

You can also set up a separate scheme for your UI tests so they can run without your unit tests:

{{< responsive-figure src="/images/testing-in-swift/ui-scheme.png" class="center" >}}

{{< responsive-figure src="/images/testing-in-swift/test-ui-scheme.png" class="center" >}}

Here we are, all set for UI tests. Let's go grab a beer and play more Ping Pong!
