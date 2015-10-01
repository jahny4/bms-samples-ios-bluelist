# IBM MobileFirst Platform for iOS Bluelist Sample App
The Bluelist sample contains Objective-C and Swift projects.  The sample uses the Cloudant NoSQL DB, Mobile Client Access, and IBM Push Notifications services.
### Downloading the samples
Clone the samples from GitHub with the following command:

    git clone https://github.com/ibm-bluemix-mobile-services/bms-samples-ios-bluelist

Select the Swift or Objective-C version of the Bluelist App:

- bluelist-swift

- bluelist-objective-c

Note: bluelist-swift requires latest version of Xcode (7.0) to compile swift 2.0 code.
Some additional configuration may be needed from Facebook if you are experiencing any authentication errors. Please follow the doc below which is provided by Facebook:

- [Facebook-iOS9](https://developers.facebook.com/docs/ios/ios9)

Also the application has updated to allow "NSAllowsArbitraryLoads" for NSAppTransportSecurity as a workaround for the Application Transport Security settings introduced in iOS 9. For more info please see the following blog:

[Connect Your iOS 9 App to Bluemix](https://developer.ibm.com/bluemix/2015/09/16/connect-your-ios-9-app-to-bluemix/)


## Setting up the Bluelist sample
For more information see [Instructions for the Bluelist sample for iOS](https://www.ng.bluemix.net/docs/starters/mobilefirst/gettingstarted/bluelist_sample_readme.html).


### Configure the back end for your Bluelist application
Before you can run the Bluelist application, you must set up an app on Bluemix.  By setting up this app, service instances for the data, push, security, and monitoring functions of the app are configured.

1. Sign up for a [Bluemix](http://bluemix.net) Account.
2. Create a mobile app.  In the Boilerplates section Bluemix catalog, click **MobileFirst Services Starter**.  Choose a **Name** and click **Create**.
3. Set up at least one Authentication method on Bluemix for your mobile App(Facebook, Google+, or Custom)
4. Optional: Configure Push. Upload APNS certificate .p12 file that corresponds to your Bundle ID.

### Deploy the Bluelist NodeJS application to Bluemix
You must use the Node.js runtime to host the Bluelist NodeJS application. Cloudant recommends operations that need 'admin' access to be performed in server side code.  A sample Node.js app for Bluelist is included in this repository.

Update the name, host and domain in the [NodeJS/manifest.yml](NodeJS/manifest.yml) file to match your Bluemix backend.

**Tip:** If your mobile app name on Bluemix has spaces, you must update the formatting of the app name and route in the `manifest.yml` file.
For example, if your app name on Bluemix is `myibmid Bluelist Sample`, make the following updates to the `manifest.yml` file:

`host: myibmid-bluelist-sample`
`name: "myibmid Bluelist Sample"`


[Download and install cf cli](http://docs.cloudfoundry.org/devguide/installcf/install-go-cli.html)

Deploy the Node.js app to Bluemix with the `cf` cli:    

- `cd NodeJS`
- `cf api https://api.ng.bluemix.net`
- `cf login`
- `cf apps`
- `cf push -f manifest.yml`



### Configure the front end in the Bluelist sample
1. Close the Bluelist project in Xcode if it is already open.
2. In a terminal, navigate to the directory that contains `Podfile` file.
3. Install Cocoapod client if not already installed `sudo gem install cocoapods`
4. Configure the Cocoapod repository if not already configured `pod setup`
3. Run the `pod install` command to download and install dependecies.
4. Open the Xcode workspace: `open BlueList.xcworkspace`. From now on, open the xcworkspace file.

### Configure the back end in the Bluelist sample
- Update the file `bluelist.plist` file with your Backend Route and App UID.  These values can be found in Bluemix.  First open your application’s dashboard, then click the App Overview tab, and navigate to the Mobile Options link:

- applicationRoute: (for example `https://mymobilefirstapp.mybluemix.net`)
- applicationId:    (for example  `db33c037-cd0c-4985-affc-92b1cf8879b1`)

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

When prompted for username and password in BlueList iOS App use `james` and `42`


[Learn more about configuring a custom identity provider](https://www.ng.bluemix.net/docs/#services/mobileaccess/security/id_provs/index-gentopic2.html#custom_id_prov)

### NEW: Enabling Encryption:

It is possible to encrypt the local data stores in order to secure data that is being stored on the device.

Prerequisite: To use the encryption functionality as explained here, you must have the IMFDataLocal/SQLCipher pod installed.

To begin the process of encrypting the local databases, you must first edit the podfile to include the IMFDataLocal/SQLCipher pod. This pod replaces the IMFDataLocal reference in the current podfile. Here is an example of the modified podfile:

    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '7.0'
    pod 'IMFDataLocal/SQLCipher'
    pod 'CloudantToolkitLocal'

A pod install must be completed after these changes have been made in order to have the correct encryption dependencies configured. To accomplish this, navigate to the Xcode project directory in terminal (in the sample: /bms-samples-ios-bluelist/bluelist-objective-c/) and run the following command:

    $ pod install

Now the project has the dependencies that are required to encrypt the local databases correctly. To encrypt these databases in your client-side code, first create an CDTEncryptionKeyProvider and then create a local data store with this keyProvider:

    //Initialize a key provider
    id<CDTEncryptionKeyProvider> keyProvider = [CDTEncryptionKeychainProvider providerWithPassword:@"password" forIdentifier:@"user"];
    //Initialize a local store
self.datastore = [self.datastoreManager datastoreNamed:self.dbName withEncryptionKeyProvider:keyProvider error:&error];
You must also use the CDTEncryptionKeyProvider that you defined when you created CDTPullReplication and CDTPushReplication:

    //pull replication
    self.pullReplication = [CDTPullReplication replicationWithSource:self.remotedatastoreurl target:self.datastore];
    [self.pullReplication addInterceptor:self.cloudantHttpInterceptor];
    //push replication
    self.pushReplication = [CDTPushReplication replicationWithSource:self.datastore target:self.remotedatastoreurl];
    [self.pushReplication addInterceptor:self.cloudantHttpInterceptor];

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


# Integrating Mobile Client Access with Cloudant Security
The IBM Mobile Client Access for Bluemix service gives your mobile application security. Cloudant has a separate security model.  The Cloudant and Mobile Client Access security models can be integrated using a small NodeJS application.  We demonstrate this integration in our [Bluelist iOS Sample](https://github.com/ibm-bluemix-mobile-services/bms-samples-ios-bluelist).  See the NodeJS folder for the application.

## BlueList NodeJS Sample
To understand the BlueList NodeJS sample that is included with BlueList, it is important to understand both [Cloudant Security](https://cloudant.com/for-developers/faq/auth/) and [Mobile Client Access](https://www.ng.bluemix.net/docs/services/mobileaccess/index.html). Once you have this foundation, the BlueList NodeJS sample is simple to understand.

The BlueList NodeJS sample has two primary functions:
1. Exchange MCA OAuth tokens for Cloudant session cookies
2. Perform BlueList's require `admin` requests to Cloudant

Using this pattern, a compromised mobile device has restricted access to Cloudant.

The sample demonstrates how to perform API requests that require `admin` access on the server where it is secure.  While it is possible to place your admin credentials on the mobile device, it is a better practice to restrict access from mobile devices.

The BlueList sample integrates Mobile Client Access security with Cloudant security.  The NodeJS sample maps a Mobile Client Access identity to a Cloudant identity.  The mobile device receives a Cloudant session cookie to perform non-admin API requests. The sample uses the Couch Security model.

### enroll REST Endpoint
The following diagram illustrates the integration performed by the BlueList NodeJS sample `/enroll` endpoint.
![MCA Cloudant Security Integration](./SecurityIntegration.png)

1. Mobile device obtains the MCA OAuth token from the MCA service.
2. Mobile device calls `/enroll` endpoint on the BlueList NodeJS.
3. BlueList NodeJS Sample validates the MCA OAuth token with the Mobile Client Access Service.
4. If valid, performs `admin` API requests to cloudant.  The sample checks for an existing Cloudant user in the `_users` database.
- If existing user, lookup Cloudant admin credentials in the `_users` database.
- If new user, use the Cloudant admin credentials, create a new Cloudant user and store in the `_users` database.
- Generate a unique database name for the user and create a remote database on Cloudant with that name.
- Give the Cloudant user permissions to read/write the newly created database.
- Create the required indexes for the BlueList application.
5. Request a new Cloudant session cookie.
6. BlueList NodeJS sample returns Cloudant session cookie, remote database name, and Cloudant URL to the mobile device.
7. Mobile device makes requests directly to Cloudant until the session cookie expiries.

### sessioncookie REST Endpoint
In the case of an expired session cookie, the mobile device can exchange a valid MCA OAuth token for a Cloudant session cookie using the `/sessioncookie` endpoint.

NEW: A Bluelist Android sample is now available that shows the interaction with Cloudant allowing optional local encryption. It can be found here:

- [bluelist-android](https://github.com/ibm-bluemix-mobile-services/bms-samples-android-bluelist)

### License
This package contains sample code provided in source code form. The samples are licensed under the under the Apache License, Version 2.0 (the "License"). You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and may also view the license in the license.txt file within this package. Also see the notices.txt file within this package for additional notices.
