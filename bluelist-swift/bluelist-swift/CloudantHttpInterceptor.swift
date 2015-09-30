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

class CloudantHttpInterceptor: NSObject, CDTHTTPInterceptor {
    
    let COOKIE_HEADER:String = "Cookie"
    
    let refreshSessionCookieUrl:NSURL
    var sessionCookie:String?
    
    init(sessionCookie:String, refreshSessionCookieUrl:NSURL){
        self.refreshSessionCookieUrl = refreshSessionCookieUrl
        self.sessionCookie = sessionCookie
    }
    
    func interceptRequestInContext(context: CDTHTTPInterceptorContext) -> CDTHTTPInterceptorContext {
        if(self.sessionCookie == nil){
            let sessionCookieSemaphore:dispatch_semaphore_t  = dispatch_semaphore_create(0)
            
            self.obtainSessionCookie({ (error) -> Void in
                context.request.addValue(self.sessionCookie!, forHTTPHeaderField: self.COOKIE_HEADER)
                dispatch_semaphore_signal(sessionCookieSemaphore)
            })
            dispatch_semaphore_wait(sessionCookieSemaphore, DISPATCH_TIME_FOREVER)
        }else{
            context.request.addValue(self.sessionCookie!, forHTTPHeaderField: COOKIE_HEADER)
        }
        return context;
    }
    
    func interceptResponseInContext(context: CDTHTTPInterceptorContext) -> CDTHTTPInterceptorContext {
        if(context.response?.statusCode == 401 || context.response?.statusCode == 403){
            let sessionCookieSemaphore:dispatch_semaphore_t  = dispatch_semaphore_create(0)
            
            self.obtainSessionCookie({ (error) -> Void in
                context.request.addValue(self.sessionCookie!, forHTTPHeaderField: self.COOKIE_HEADER)
                context.shouldRetry = true
                dispatch_semaphore_signal(sessionCookieSemaphore)
            })
            dispatch_semaphore_wait(sessionCookieSemaphore, DISPATCH_TIME_FOREVER)
        }
        return context;
    }
    
    func obtainSessionCookie(completionHandler:(error:NSError?)->Void){
        IMFAuthorizationManager.sharedInstance().obtainAuthorizationHeaderWithCompletionHandler { (response, error) -> Void in
            if(error != nil){
                completionHandler(error: error)
            }else{
                let request:NSMutableURLRequest = NSMutableURLRequest(URL: self.refreshSessionCookieUrl)
                request.HTTPMethod = "POST"
                request.addValue(IMFAuthorizationManager.sharedInstance().cachedAuthorizationHeader, forHTTPHeaderField: "Authorization")
                NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
                    if(error != nil){
                        completionHandler(error: error)
                    }else{
                        let httpStatus = (response as! NSHTTPURLResponse).statusCode
                        if(httpStatus != 200){
                            completionHandler(error: NSError(domain: "BlueList", code: 42, userInfo: [NSLocalizedDescriptionKey : "Invalid HTTP Status \(httpStatus).  Check NodeJS application on Bluemix"]))
                        }else{
                            if(data == nil){
                                completionHandler(error: NSError(domain: "BlueList", code: 42, userInfo: [NSLocalizedDescriptionKey : "No JSON data returned from enroll call.  Check NodeJS application on Bluemix"]))
                            }else{
                                do{
                                    let jsonObject:NSDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(rawValue: 0)) as! NSDictionary
                                    let sessionCookie = jsonObject["sessionCookie"]! as! String
                                    self.sessionCookie = sessionCookie
                                    completionHandler(error: nil)
                                }catch let error as NSError{
                                    completionHandler(error: NSError(domain: "BlueList", code: 42, userInfo: [NSLocalizedDescriptionKey : "No JSON data returned from enroll call.  Check NodeJS application on Bluemix. Error: \(error)"]))
                                }
                            }

                        }
                    }
                }).resume()
            }
        }
    }
}
