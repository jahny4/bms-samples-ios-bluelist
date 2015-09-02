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

class AuthenticationViewController: UIViewController {

    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var errorTextView: UITextView!
    var userId:String?;
    let logger = IMFLogger(forName: "BlueList")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        authenticateUser()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func authenticateUser(){
        logger?.logInfoWithMessages("Trying to authenticate User")
        progressLabel.text = "Authenticating"
        if checkIMFClient() && checkAuthenticationConfig(){
            getAuthToken()
        }
        
    }
    
    
    func getAuthToken() {
        let authManager = IMFAuthorizationManager.sharedInstance()
        authManager.obtainAuthorizationHeaderWithCompletionHandler { (response:IMFResponse!, error:NSError!) -> Void in
            var errorMsg: String
            if error != nil {
                errorMsg = "Error obtaining Authentication Header.\nCheck Bundle Identifier and Bundle version string, short in Info.plist match exactly to the ones in AMA, or check the applicationId in bluelist.plist\n\n"
                if let responseText = response?.responseText {
                    errorMsg += "\(responseText)\n"
                }
                if let errorDescription = error?.userInfo?.description {
                    errorMsg += "\(errorDescription)\n"
                }
                
                self.invalidAuthentication(errorMsg)
            } else {
                //lets make sure we have an user id before transitioning, IMFDataManager needs this for permissions
                if let userIdentity = authManager.userIdentity as NSDictionary?
                {
                    if let userid = userIdentity.valueForKey("id") as! String? {
                        self.userId = userid;
                        self.logger?.logInfoWithMessages("Authenticated user with id \(userid)")
                        //User is authenticated show main UI
                        self.showMainApplication()
                        let mainApplication = UIApplication.sharedApplication()
                        if let delegate = mainApplication.delegate as? AppDelegate {
                            //Allow logs to be sent to remote server now that User is Authenticated
                            delegate.isUserAuthenticated = true
                        }
                    } else {
                        self.invalidAuthentication("Valid Authentication Header and userIdentity, but id not found")
                    }
                } else {
                    self.invalidAuthentication("Valid Authentication Header, but userIdentity not found. You have to configure one of the methods available in Advanced Mobile Service on Bluemix, such as Facebook, Google, or Custom ")
                }
            }
        }
    }
    
    func checkIMFClient() -> Bool{
        let imfclient = IMFClient.sharedInstance()
        let route = imfclient.backendRoute
        let uid = imfclient.backendGUID

        if route == nil || route.isEmpty {
            invalidAuthentication("Invalid Route.\n Check applicationRoute in bluelist.plist")
            return false
        }
        if uid == nil || uid.isEmpty {
            invalidAuthentication("Invalid UID.\n Check applicationId in bluelist.plist")
            return false
        }
        return true
    }
    
    func checkAuthenticationConfig() -> Bool {
        
        if isFacebookConfigured() {
            progressLabel.text = "Facebook Login"
            return true
        } else if isCustomConfigured() {
            progressLabel.text = "Custom Login"
            return true
        } else if isGoogleConfigured() {
            progressLabel.text = "Google Login"
            return true
        }
    
        invalidAuthentication("Authentication is not configured in Info.plist. You have to configure Info.plist with the same Authentication method configured on Bluemix such as Facebook, Google, or Custom. Check the README.md file for more instructions")
        return false
    }
    
    func isFacebookConfigured() -> Bool {
        let facebookAppID = NSBundle.mainBundle().objectForInfoDictionaryKey("FacebookAppID") as! String;
        let facebookDisplayName = NSBundle.mainBundle().objectForInfoDictionaryKey("FacebookDisplayName") as! String;
        let urlTypes = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleURLTypes") as! NSArray;
        let urlType0 = urlTypes[0] as! NSDictionary;
        let urlSchemes = urlType0["CFBundleURLSchemes"] as! NSArray
        let facebookURLScheme = urlSchemes[0] as! String

        if facebookAppID.isEmpty || facebookAppID == "123456789" {
            return false
        }
        if facebookDisplayName.isEmpty {
            return false
        }
        if facebookURLScheme.isEmpty || facebookURLScheme == "fb123456789" || !facebookURLScheme.hasPrefix("fb") {
            return false
        }
        logger?.logInfoWithMessages("Facebook Authentication Configured:\nFacebookAppID \(facebookAppID)\nFacebookDisplayName \(facebookDisplayName)\nFacebookURLScheme \(facebookURLScheme)")
        return true
    }
    
    func isGoogleConfigured() -> Bool {
        let urlTypes = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleURLTypes") as! NSArray;
        let urlType1 = urlTypes[1] as! NSDictionary;
        let urlIdentifier = urlType1["CFBundleURLName"] as! String
        let urlSchemes = urlType1["CFBundleURLSchemes"] as! NSArray
        let googleURLScheme = urlSchemes[0] as! String
        
        if urlIdentifier.isEmpty  {
            return false
        }
        if googleURLScheme.isEmpty || googleURLScheme != urlIdentifier {
            return false
        }
        logger?.logInfoWithMessages("Google Authentication Configured:\nURL Identifier \(urlIdentifier)\nURL Scheme \(googleURLScheme)")
        return true
    }
    
    func isCustomConfigured() -> Bool {
        let customAuthenticationRealm = NSBundle.mainBundle().objectForInfoDictionaryKey("CustomAuthenticationRealm") as! String;
        if customAuthenticationRealm.isEmpty {
            return false
        }
        logger?.logInfoWithMessages("Custom Authentication Configured:\nCustomAuthenticationRealm \(customAuthenticationRealm)")
        return true
    }
    
    func invalidAuthentication(message:String){
        progressLabel.text = "Error Authenticating"
        errorTextView.text = ""
        errorTextView.text = errorTextView.text.stringByAppendingString(message)
        logger.logErrorWithMessages(message)
        
        if let delegate = UIApplication.sharedApplication().delegate as? AppDelegate {
          delegate.clearKeychain()
        }
    }
    
    func showMainApplication(){
        self.performSegueWithIdentifier("authenticationSegue", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        let navVC = segue.destinationViewController as! UINavigationController
        let listTableVC = navVC.topViewController as! ListTableViewController
        listTableVC.userId = self.userId
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
