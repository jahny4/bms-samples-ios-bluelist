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
    var userId:String?
    var remotedatastoreurl:NSURL?
    var dbName:String?
    var cloudantHttpInterceptor:CDTHTTPInterceptor?
    
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
                errorMsg = "Error obtaining Authentication Header.\nCheck to see if Authentication settings in the Info.plist match exactly to the ones in MCA, or check the applicationId and applicationRoute in bluelist.plist\n\n"
                if let responseText = response?.responseText {
                    errorMsg += "\(responseText)\n"
                }
                if let errorDescription = error?.userInfo.description {
                    errorMsg += "\(errorDescription)\n"
                }
                
                self.invalidAuthentication(errorMsg)
            } else {
                //lets make sure we have an user id before transitioning
                if let userIdentity = authManager.userIdentity as NSDictionary?
                {
                    if let userid = userIdentity.valueForKey("id") as! String? {
                        self.userId = userid;
                        self.logger?.logInfoWithMessages("Authenticated user with id \(userid)")
                        
                        self.enrollUser(self.userId!, completionHandler: { (error) -> Void in
                            if((error) != nil){
                                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                                    self.invalidAuthentication("Enroll failed to create remote cloudant database for \(self.userId).  Error: \(error)")
                                })
                            }else{
                                //User is authenticated show main UI
                                self.showMainApplication()
                                let mainApplication = UIApplication.sharedApplication()
                                if let delegate = mainApplication.delegate as? AppDelegate {
                                    //Allow logs to be sent to remote server now that User is Authenticated
                                    delegate.isUserAuthenticated = true
                                }
                            }
                        })
                        
                    } else {
                        self.invalidAuthentication("Valid Authentication Header and userIdentity, but id not found")
                    }
                } else {
                    self.invalidAuthentication("Valid Authentication Header, but userIdentity not found. You have to configure one of the methods available in Advanced Mobile Service on Bluemix, such as Facebook, Google, or Custom ")
                }
            }
        }
    }

    func enrollUser(userId:String, completionHandler:(error:NSError?)->Void){
        let enrollUrlString = "\(IMFClient.sharedInstance().backendRoute)/bluelist/enroll"
        let enrollUrl = NSURL(string: enrollUrlString)
        
        let request = NSMutableURLRequest(URL: enrollUrl!)
        request.HTTPMethod = "PUT"
        request.addValue(IMFAuthorizationManager.sharedInstance().cachedAuthorizationHeader, forHTTPHeaderField: "Authorization")

        NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
            if(error != nil){
                completionHandler(error: error);
                return;
            }
            
            let httpStatus = (response as! NSHTTPURLResponse).statusCode
            if(httpStatus != 200){
                completionHandler(error: NSError(domain: "BlueList", code: 42, userInfo: [NSLocalizedDescriptionKey : "Invalid HTTP Status \(httpStatus).  Check NodeJS application on Bluemix"]))
                return;
            }
            
            if(data != nil){
                do{
                    let jsonObject:NSDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(rawValue: 0)) as! NSDictionary
                    let cloudantAccess:NSDictionary = jsonObject["cloudant_access"] as! NSDictionary
                    let cloudantHost:String = cloudantAccess["host"]! as! String
                    let cloudantPort:Int = cloudantAccess["port"]! as! Int
                    let cloudantProtocol:String = cloudantAccess["protocol"]! as! String
                    self.dbName = jsonObject["database"]! as? String
                    let sessionCookie = jsonObject["sessionCookie"]! as! String
                    
                    let dbName:String = self.dbName!
                    let remotedatastoreurlstring:String = "\(cloudantProtocol)://\(cloudantHost):\(cloudantPort)/\(dbName)"
                    self.remotedatastoreurl = NSURL(string: remotedatastoreurlstring)
                    let refreshUrlString:String = "\(IMFClient.sharedInstance().backendRoute)/bluelist/sessioncookie"
                    
                    self.cloudantHttpInterceptor = CloudantHttpInterceptor(sessionCookie: sessionCookie, refreshSessionCookieUrl: NSURL(string: refreshUrlString)!)
                    completionHandler(error: nil)
                }catch let error as NSError{
                    completionHandler(error: NSError(domain: "BlueList", code: 42, userInfo: [NSLocalizedDescriptionKey : "No JSON data returned from enroll call.  Check NodeJS application on Bluemix. Error: \(error)"]))
                }
            }
            
        }.resume()
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
        listTableVC.dbName = self.dbName
        listTableVC.remotedatastoreurl = self.remotedatastoreurl
        listTableVC.cloudantHttpInterceptor = self.cloudantHttpInterceptor
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
