# IBM MobileFirst Platform for iOS Bluelist Sample App 
The Bluelist sample contains Objective-C and Swift projects that you can use to learn about the Beta.  The sample uses the Cloudant NoSQL DB, Advanced Mobile Access, and Push-iOS8 Beta services.
### Downloading the samples
Clone the samples from IBM DevOps Services with the following command:

    git clone https://hub.jazz.net/git/mobilecloud/imf-bluelist

Select the Swift or Objective-C version of the Bluelist App:

- [bluelist-swift](https://hub.jazz.net/project/mobilecloud/imf-bluelist/overview#https://hub.jazz.net/gerrit/plugins/gerritfs/list/mobilecloud%252Fimf-bluelist/refs%252Fheads%252Fmaster/bluelist-swift)

- [bluelist-objective-c](https://hub.jazz.net/project/mobilecloud/imf-bluelist/overview#https://hub.jazz.net/gerrit/plugins/gerritfs/list/mobilecloud%252Fimf-bluelist/refs%252Fheads%252Fmaster/bluelist-objective-c)

Note: bluelist-swift requires latest version of Xcode (6.3) to compile swift 1.2 code.

NEW: A simple Android sample is now avaible that shows the interaction with Cloudant allowing optional local encryption. It can be found here:

- [bluelist-android](https://hub.jazz.net/project/mobilecloud/imf-bluelist/overview#https://hub.jazz.net/git/mobilecloud%2Fimf-bluelist/list/master/bluelist-android)

## Setting up the Bluelist sample
For more information see [Getting started with IBM MobileFirst Platform for iOS](https://www.ng.bluemix.net/docs/#starters/mobilefirst/gettingstarted/index.html#gettingstarted). Also checkout developerWorks tutorial [Build an iOS 8 App with Bluemix and the MobileFirst Platform for iOS](http://www.ibm.com/developerworks/mobile/library/mo-mfp-ios8-app/index.html)


### Configure the back end for your Bluelist application
Before you can run the Bluelist application, you must set up an app on Bluemix.  By setting up this app, service instances for the data, push, security, and monitoring functions of the app are configured.
1. Sign up for a [Bluemix](http://bluemix.net) Account. 
2. Create a mobile app.  In your dashboard, click **CREATE AN APP**.  Choose **MOBILE** > **iOS 8 BETA**.
3. Register Bluelist as a mobile client. Use your Bundle ID (for example: `com.ibm.Bluelist`) and version (for example: `1.0.0`)  These values can be found in Xcode, under Supporting Files/Info.plist
4. Set up at least one Authentication method on Bluemix for your mobile App(Facebook, Google+, or Custom)
5. Optional: Configure Push. Upload APNS certificate .p12 file that corresponds to your Bundle ID.



### Configure the front end in the Bluelist sample
1. Close the Bluelist project in Xcode if it is already open. 
2. In a terminal, navigate to the directory that contains `Podfile` file.
3. Install Cocoapod client if not already installed `sudo gem install cocoapods`
4. Configure the Cocoapod repository if not already configured `pod setup`
3. Run the `pod install` command to download and install dependecies.
4. Open the Xcode workspace: `open BlueList.xcworkspace`. From now on, open the xcworkspace file.

### Configure the back end in the Bluelist sample
- Update the file `bluelist.plist` file with your Backend Route and App UID.  These values can be found in Bluemix.  First open your application’s dashboard, then click the AMA Service, and navigate to the Client Registration tab:

- applicationRoute: (for example `https://mymobilefirstapp.mybluemix.net`)
- applicationId:    (for example  `db33c037-cd0c-4985-affc-92b1cf8879b1`)

- Update the `Info.plist` file bundle identifier and bundle version string to exactly match the values that you used when you registered the mobile client.   
- Bundle Identifier: (for example `com.ibm.BlueList`)
- Bundle version string: (for example `1.0.0`)

## Set up at least one authentication method

You can set up Facebook, Google, or custom authentication. 
####Facebook authentication

Update the `Info.plist` file with your Facebook App information:

- FacebookAppID: (For example `1581349575427190` , You can get App ID from Facebook developer console)
- FacebookDisplayName: (For example `BlueList`  , You can get App name from Facebook developer console)

Update URL Types, Item 0, URL Schemes, update Item 0 as follows:

- URL Schemes: (for example `fb1581349575427190` , fb+Client ID from Facebook developer console)
[Learn more about using Facebook as an identity provider](https://www.ng.bluemix.net/docs/#services/mobileaccess/security/id_provs/index-gentopic2.html#usingfacebookauthentication)    

####Google authentication

Update the `Info.plist` file with your Google App information:

Update URL Types (Item 1) 

- Under URL Types update URL Schemes like this:
- URL Identifier: (for example `com.ibm.BlueList` , You can find Bundle ID used in google developer console)
- URL Schemes: (for example `com.ibm.BlueList` , You can find the Bundle ID used in google developer console)
[Learn more about using Google as an identity provider](https://www.ng.bluemix.net/docs/#services/mobileaccess/security/id_provs/index-gentopic2.html#google_auth)

####Custom authentication

Update the `Info.plist` file with your Custom Realm information:

- CustomAuthenticationRealm: (for example `customAuthRealm_1`, Same value used in Bluemix Advanced Mobile Access service)

You can use the Node.js runtime to host the authentication service. A sample Node.js app for authentication is included in this repository.

Update the name, host and domain in the [custom-auth-nodejs/manifest.yml](custom-auth-nodejs/manifest.yml) file to match your Bluemix backend.

**Tip:** If your mobile app name on Bluemix has spaces, you must update the formatting of the app name and route in the `manifest.yml` file. 
For example, if your app name on Bluemix is `myibmid Bluelist Sample`, make the following updates to the `manifest.yml` file:

`host: myibmid-bluelist-sample`
`name: "myibmid Bluelist Sample"`


[Download and install cf cli](http://docs.cloudfoundry.org/devguide/installcf/install-go-cli.html)

Deploy the Node.js app to Bluemix with the `cf` cli:    

$ cd custom-auth-nodejs
$ cf api https://api.ng.bluemix.net
$ cf login
$ cf apps
$ cf push

When prompted for username and password in BlueList iOS App use `john` and `123`


[Learn more about configuring a custom identity provider](https://www.ng.bluemix.net/docs/#services/mobileaccess/security/id_provs/index-gentopic2.html#custom_id_prov)

### NEW: Enabling Encryption:

It is possible to encrypt the local data stores in order to secure data that is being stored on the device.

Prerequisite: To use the encryption functionality as explained here, you must have the IMFDataLocal/SQLCipher pod installed.

To begin the process of encrypting the local databases, you must first edit the podfile to include the IMFDataLocal/SQLCipher pod. This pod replaces the IMFDataLocal reference in the current podfile. Here is an example of the modified podfile:

    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '7.0'
    pod 'IMFDataLocal/SQLCipher'
    pod 'CloudantToolkitLocal'

A pod install must be completed after these changes have been made in order to have the correct encryption dependencies configured. To accomplish this, navigate to the Xcode project directory in terminal (in the sample: /mfp-bluelist-on-premises/iOS/objective-c/) and run the following command:

    $ pod install

Now the project has the dependencies that are required to encrypt the local databases correctly. To encrypt these databases in your client-side code, first create an CDTEncryptionKeyProvider and then create a local data store with this keyProvider:

    //Initialize a key provider
    id<CDTEncryptionKeyProvider> keyProvider = [CDTEncryptionKeychainProvider providerWithPassword:@"password" forIdentifier:@"user"];
    //Initialize a local store
    self.datastore = [manager localStore:dbname withEncryptionKeyProvider:keyProvider error:&dbCreateError];

You must also use the CDTEncryptionKeyProvider that you defined when you created CDTPullReplication and CDTPushReplication:

    //pull replication
    self.pullReplication   = [[IMFDataManager sharedInstance] pullReplicationForStore:dbname withEncryptionKeyProvider:keyProvider];
    //push replication
    self.pushReplication   = [[IMFDataManager sharedInstance] pushReplicationForStore:dbname withEncryptionKeyProvider:keyProvider];

In the sample application, the encryption code is already provided in the TableViewController. By default, encryption is not enabled until an encryptionPassword is provided in the bluelist.plist file. After encryptionPassword is configured, the application uses this password to encrypt the local data store by using the above mechanisms. If encryptionPassword is left blank in the bluelist.plist file, encryption does not occur.

For more information on Encrypting Data please see the following doc:

[Encrypting data on a the device](https://www.ng.bluemix.net/docs/services/data/index.html#t_data_encrypt)



### Run the iOS App    


Now you can run your iOS application in your mobile emulator or on your device.

Add items, change priorities, and replicate with the cloud by pulling down to refresh.

Notice that your data items have persisted. You now have data on the cloud!


## Push Notifications
**You can not use the default App Bundle ID `com.ibm.BlueList`, you need to get a unique App Bundle ID from Apple to be able to test push notifications**

### Configuring the Apple Push Notification service (APNs)
To use to send notifications, you must upload the SSL certificates that are required for Apple Push Notification service (APNs).

The certificates that are needed for APNs are .p12 certificates, which contain the private key and SSL certificates that are required to build and publish your application. You must generate the certificates from the Member Center of the [Apple Developer](http://developer.apple.com) website (for which a valid Apple Developer account is required). Separate certificates are required for the development environment (also known as sandbox) and the production environment.

You can add the p12 certificates to your application from the Configuration tab in the Push dashboard. After the certificates are uploaded successfully, you can start sending notifications.

For more information about using the APNs, see [iOS Developer Library: Local and Push Notification Programming Guide](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ProvisioningDevelopment.html#//apple_ref/doc/uid/TP40008194-CH104-SW4).

### Register Device for Push 
Run the App on a real device, push is not supported on iOS Simulator.
After App connects to Bluemix and the TODO items show up, tap the settings icon to see the settings view.
From the settings view turn on notifications, this will register the device with the Push service that you configured on Bluemix.

You can stop the application by closing the App or put on the background by pressing the home button on the iOS Device.
When the App is not running or in the background, you will be able to see the push notification on the lock screen or from the iOS home screen, when you send the push notification.

### Test sending notifications from Bluemix
1. Log in to Bluemix.
2. From the DASHBOARD view, click your application.
3. Click the Push service icon.
4. Click the Notification tab.
5. Select all ecipients
6. Compose a notification by filling in the Message text field with anything you want, and click NEXT.
7. Confirm message and Click SEND.
Watch as your mobile device receives a push notification!

### Test Interactive Push notifications
Compose a push notification and use the value `TODO_CATEGORY` for the push category.
When you receive the push message on the iOS device you can swipe the message on the lock screen to the left, or pull down the push message from the iOS home screen.

### License
This package contains sample code provided in source code form. The samples are licensed under the under the Apache License, Version 2.0 (the "License"). You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and may also view the license in the license.txt file within this package. Also see the notices.txt file within this package for additional notices.
