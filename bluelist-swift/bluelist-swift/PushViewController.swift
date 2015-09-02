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


import Foundation

class PushViewController: UITableViewController {
    var availableTags: [String] = []
    var subscribedTags: [String] = []
    
    let logger            = IMFLogger(forName: "BlueList")
    let push              = IMFPushClient.sharedInstance()
    let theSwitch         = UISwitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getAvailableTags()
        theSwitch.addTarget(self, action: "notificationsSwitchChanged:", forControlEvents: UIControlEvents.ValueChanged)
    }
    
    @IBAction func performDone(sender: UIBarButtonItem) {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: { () -> Void in
        })
    }
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows
        return section == 0 ? 1 : availableTags.count
    }
      
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell
        if indexPath.section == 0 {
            //define cell
            cell = tableView.dequeueReusableCellWithIdentifier("PushCell", forIndexPath: indexPath) as! UITableViewCell
            cell.accessoryView = theSwitch
            //see if device is subscribed for all push notifications
            if isPushEnabled() {
                theSwitch.on = true
            } else {
                theSwitch.on = false
            }
        } else {
            //define cell
            cell = tableView.dequeueReusableCellWithIdentifier("TagCell", forIndexPath: indexPath) as! UITableViewCell
            //add label to cell
            let subscriptionTag = self.availableTags[indexPath.row]
            cell.textLabel?.text = subscriptionTag
            cell.accessoryView?.hidden = false
            //show checkmark is subscribed
            if isTagSubscribed(subscriptionTag) {
                cell.accessoryType = UITableViewCellAccessoryType.Checkmark
            } else {
                cell.accessoryType = UITableViewCellAccessoryType.None
            }
        }
        return cell
    }
    
    //if the push notifications switch changed, this gets called
    func notificationsSwitchChanged(sender:UISwitch) {
        let application = UIApplication.sharedApplication()
        if (sender.on == true) {
            registerForPushNotification(application)
        } else {
            unregisterForPushNotifications(application)
        }
        
    }
    
    //on selection of subscription notifications
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section != 0 && theSwitch.on {
            tableView.deselectRowAtIndexPath(tableView.indexPathForSelectedRow()!, animated: false)
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            //toggle the checkmark, subscribe or unsubscribe from tags, set user defaults
            if (cell?.accessoryType == UITableViewCellAccessoryType.None) {
                subscribeTag(availableTags[indexPath.row])
                cell?.accessoryType = UITableViewCellAccessoryType.Checkmark
            } else {
                unsubscribeTag(availableTags[indexPath.row])
                cell?.accessoryType = UITableViewCellAccessoryType.None
            }
        }
    }
    
    func subscribeTag(theTag: String) {
        let tagArray = [theTag]
        push.subscribeToTags(tagArray, completionHandler: { (response: IMFResponse!, error: NSError!) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error push subscribeToTags \(error.description)")
            }
        })
    }
    
    func unsubscribeTag(theTag: String) {
        let tagArray = [theTag]
        push.unsubscribeFromTags(tagArray, completionHandler: { (response: IMFResponse!, error: NSError!) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error in unsubscribing to tags \(error.description)")
            }
        })
    }
    
    func getAvailableTags() {
        push.retrieveAvailableTagsWithCompletionHandler { (response: IMFResponse!, error: NSError!) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error push retrieveAvailableTagsWithCompletionHandler \(error.description)")
            } else {
                self.availableTags = response.availableTags() as! [String]
                self.getSubscribedTags()
            }
        }
    }
    
    func getSubscribedTags() {
        push.retrieveSubscriptionsWithCompletionHandler { (response: IMFResponse!, error: NSError!) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error push retrieveSubscriptionsWithCompletionHandler \(error.description)")
            } else {
                let subscriptions = response.subscriptions()
                self.subscribedTags = subscriptions["subscriptions"] as! [String]
                self.tableView?.reloadData()
            }
        }
    }
    
    func isTagSubscribed(tag: String) -> Bool {
        for subscribedTag in self.subscribedTags {
            if subscribedTag == tag {
                return true
            }
        }
        return false;
    }
    
    func isPushEnabled() -> Bool {
        return isTagSubscribed("Push.ALL")
    }
    
    func registerForPushNotification(application:UIApplication) {
        //Registering for remote Notifications must be done after User is Authenticated
        //setup push with interactive notifications
        let acceptAction = UIMutableUserNotificationAction()
        acceptAction.identifier = "ACCEPT_ACTION"
        acceptAction.title = "Accept"
        acceptAction.destructive = false
        acceptAction.authenticationRequired = false
        acceptAction.activationMode = UIUserNotificationActivationMode.Foreground
        
        let declineAction = UIMutableUserNotificationAction()
        declineAction.identifier = "DECLINE_ACTION"
        declineAction.title = "Decline"
        declineAction.destructive = true
        declineAction.authenticationRequired = false
        declineAction.activationMode = UIUserNotificationActivationMode.Background
        
        let pushCategory = UIMutableUserNotificationCategory()
        pushCategory.identifier = "TODO_CATEGORY"
        pushCategory.setActions([acceptAction, declineAction], forContext: UIUserNotificationActionContext.Default)
        
        let notificationTypes: UIUserNotificationType = UIUserNotificationType.Badge | UIUserNotificationType.Alert | UIUserNotificationType.Sound
        let notificationSettings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: notificationTypes, categories: NSSet(array:[pushCategory]) as Set<NSObject>)
        
        application.registerUserNotificationSettings(notificationSettings)
        
        if UIDevice.currentDevice().model.hasSuffix("Simulator") {
            logger?.logInfoWithMessages("Running on Simulator skiping remote push notifications")
        } else {
            logger?.logInfoWithMessages("Running on Device registering for push notifications")
            application.registerForRemoteNotifications()
        }
    }
    
    func unregisterForPushNotifications(application: UIApplication) {
        //unregister the application for push notifications
        let push = IMFPushClient.sharedInstance()
        push.unregisterDevice { (response: IMFResponse!, error: NSError!) -> Void in
            if error != nil {
                self.logger?.logErrorWithMessages("Error during device unregistration \(error.description)")
                return
            } else {
                self.logger?.logInfoWithMessages("Succesfully Unregistered Device")
                application.unregisterForRemoteNotifications()
                self.getAvailableTags()
            }
        }
    }
}