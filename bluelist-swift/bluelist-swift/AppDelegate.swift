// Copyright 2014, 2015 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import UIKit
import Security

let IBM_SYNC_ENABLE = true

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var logger:IMFLogger?
    var tags = [String]()
    var isUserAuthenticated = false
    
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        //handle Google Plus or Facebook login
        return GPPURLHandler.handleURL(url, sourceApplication: sourceApplication, annotation: annotation) || FBAppCall.handleOpenURL(url, sourceApplication: sourceApplication)
        
    }
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        //for debuging different authentication methods, this clears the backend oauth token, if a token is found then it's used
        //clearKeychain()
        
        // Read the applicationId from the bluelist.plist.
        let configurationPath = NSBundle.mainBundle().pathForResource("bluelist", ofType: "plist")
        let configuration = NSDictionary(contentsOfFile: configurationPath!)
        let applicationId = configuration?["applicationId"] as! String
        let applicationRoute = configuration?["applicationRoute"] as! String
        println("Intializing IMFCLient")
        println("applicationRoute " + applicationRoute)
        println("applicationId " + applicationId)
        IMFClient.sharedInstance().initializeWithBackendRoute(applicationRoute, backendGUID: applicationId)
        
        /*Authentication is required to connect to backend services,
        For this sample App, we register all 3 handlers but only 1 will be use
        depending how the client was register in AMA (Advance Mobile Access)
        */
        IMFFacebookAuthenticationHandler.sharedInstance().registerWithDefaultDelegate()
        IMFGoogleAuthenticationHandler.sharedInstance().registerWithDefaultDelegate()
        let customAuthenticationRealm = NSBundle.mainBundle().objectForInfoDictionaryKey("CustomAuthenticationRealm") as! String;
        IMFClient.sharedInstance().registerAuthenticationDelegate(CustomAuth(), forRealm: customAuthenticationRealm)
        
        //Analytics and Monitoring
        IMFLogger.captureUncaughtExceptions() // capture and record uncaught exceptions (crashes)
        IMFLogger.setLogLevel(IMFLogLevel.Error) // setting the verbosity filter. Change to Info to get more logging output
        IMFAnalytics.sharedInstance().startRecordingApplicationLifecycleEvents() // automatically record app startup times and foreground/background events
        
        logger = IMFLogger(forName: "BlueList")
        
        //Registering for remote Notifications must be done after User is Authenticated, this is done from PushViewController by calling function registerForPushNotification(application:UIApplication)
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // Consider if these calls should be in applicationDidEnterBackground and/or other application lifecycle event.
        // Perhaps [IMFLogger send]; should only happen when the end-user presses a button to do so, for example.
        // CAUTION: the URL receiving the uploaded log and analytics payload is auth-protected, so these calls
        // should only be made after authentication, otherwise your end-user will receive a random auth prompt!
        if isUserAuthenticated {
            IMFLogger.send() // send all IMFLogger logged data to the server
            IMFAnalytics.sharedInstance().sendPersistedLogs() // send all analytics data to the server
        }
        
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        logger?.logWarnWithMessages("didFailToRegisterForRemoteNotificationsWithError \(error.description)")
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        logger?.logInfoWithMessages("didRegisterForRemoteNotificationsWithDeviceToken \(deviceToken.description)")
        let push = IMFPushClient.sharedInstance()
        logger?.logInfoWithMessages("Registering with backend")
        push.registerDeviceToken(deviceToken, completionHandler: { (response, error) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error during device registration \(error.description)")
                return
            }
            self.logger?.logInfoWithMessages("Response during device registration json: \(response.responseJson.description)")
            println("Succesfully Registered Device \(deviceToken.description)")
        })
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        self.logger?.logInfoWithMessages("didReceiveRemoteNotification fetchCompletionHandler userInfo: \(userInfo.description)")
        let contentAPS = userInfo["aps"] as! [NSObject : AnyObject]
        if let contentAvailable = contentAPS["content-available"] as? Int {
            logger?.logInfoWithMessages(" silent or mixed push...")
            logger?.logInfoWithMessages(" contentAvailable:  \(contentAvailable)")
            //Perform background task
            if contentAvailable == 1 {
                completionHandler(UIBackgroundFetchResult.NewData)
            } else {
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        } else {
            logger?.logInfoWithMessages("default push...")
            completionHandler(UIBackgroundFetchResult.NoData)
        }
        if let push = IMFPushClient.sharedInstance() {
            push.application(application, didReceiveRemoteNotification: userInfo)
        }
        
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        logger?.logInfoWithMessages("actionable notificaiton received")
        completionHandler()
    }
    
    // helper functions for debuging
    func deleteAllKeysForSecClass(secClass: CFTypeRef) {
        let dict = NSMutableDictionary()
        let kSecAttrAccessGroupSwift = NSString(format: kSecClass)
        dict.setObject(secClass, forKey: kSecAttrAccessGroupSwift)
        SecItemDelete(dict)
    }
    
    func clearKeychain () {
        deleteAllKeysForSecClass(kSecClassIdentity)
        deleteAllKeysForSecClass(kSecClassGenericPassword)
        deleteAllKeysForSecClass(kSecClassInternetPassword)
        deleteAllKeysForSecClass(kSecClassCertificate)
        deleteAllKeysForSecClass(kSecClassKey)
    }
    
    
}

