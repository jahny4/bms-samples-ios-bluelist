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


class ListTableViewController: UITableViewController, UITextFieldDelegate, CDTReplicatorDelegate{

    
    //Priority Images
    var highImage   = UIImage(named: "priorityHigh.png")
    var mediumImage = UIImage(named: "priorityMedium.png")
    var lowImage    = UIImage(named: "priorityLow.png")
    
    var userId:String!
    
    @IBOutlet var segmentFilter: UISegmentedControl!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    //Intialize some list items
    var itemList: [TodoItem] = []
    var filteredListItems = [TodoItem]()
    
    var idTracker = 0

    // Cloud sync properties
    var dbName:String = "todosdb"
    var datastore: CDTStore!
    var remoteStore: CDTStore!
    
    var replicatorFactory: CDTReplicatorFactory!
    
    var pullReplication: CDTPullReplication!
    var pullReplicator: CDTReplicator!
    
    var pushReplication: CDTPushReplication!
    var pushReplicator: CDTReplicator!
    
    var doingPullReplication: Bool!
    
    //logger
    let logger = IMFLogger(forName: "BlueList")
    

    
    //MARK: - ViewController functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Setting up the refresh control
        settingsButton.enabled = false
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: Selector("handleRefreshAction") , forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl?.beginRefreshing()
        self.dbName = self.dbName + "_" + self.userId
        self.setupIMFDatabase(self.dbName)
        
        //Logging
        self.logger.logInfoWithMessages("this is a info test log in ListTableViewController:viewDidLoad")
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: - Data Management
    
    func setupIMFDatabase(dbName: String) {
        var error:NSError?
        var dbName = dbName
        var encryptionEnabled:Bool = false
        let configurationPath = NSBundle.mainBundle().pathForResource("bluelist", ofType: "plist")
        let configuration = NSDictionary(contentsOfFile: configurationPath!)
        let encryptionPassword = configuration?["encryptionPassword"] as! String
        if(encryptionPassword.isEmpty){
            encryptionEnabled = false
        }
        else {
            encryptionEnabled = true
            dbName = dbName + "secure"
        }
        //CDTEncryptionKeyProvider used for encrypting local datastore
        var keyProvider:CDTEncryptionKeyProvider!
        let manager = IMFDataManager.sharedInstance() as IMFDataManager
        //create a local data store. Encrypt the local store if the setting is enabled
        if(encryptionEnabled){
            //Initialize the key provider
            keyProvider = CDTEncryptionKeychainProvider(password: encryptionPassword, forIdentifier:"bluelist")
            NSLog("%@", "Attempting to create an encrypted local data store")
            //Initialize the encrypted store
            self.datastore = manager.localStore(dbName, withEncryptionKeyProvider: keyProvider, error: &error)
        }
        else{
            NSLog("%@","Attempting to create a local data store")
            self.datastore = manager.localStore(dbName, error: &error)
        }
        if ((error) != nil) {
            NSLog("%@", "Could not create local data store with name " + dbName)
            if(encryptionEnabled){
                let alert:UIAlertView = UIAlertView(title: "Error", message: "Could not create an encrypted local store with credentials provided. Check the encryptionPassword in the bluelist.plist file.", delegate:self , cancelButtonTitle: "Okay")
                alert.show()
                return
            }
        }
        else{
            NSLog("%@", "Local data store create successfully: " + dbName)
        }

               self.datastore.mapper.setDataType("TodoItem", forClassName: NSStringFromClass(TodoItem.classForCoder()))
        
        if (!IBM_SYNC_ENABLE) {
            self.listItems({ () -> Void in
                self.logger.logDebugWithMessages("Done refreshing we are not using cloud")
                self.refreshControl?.endRefreshing()
            })
            return
        }
        manager.remoteStore(dbName as String, completionHandler: { (store, error) -> Void in
            if (error != nil) {
                self.logger.logErrorWithMessages("Error creating remote data store \(error)")
            } else {
                self.remoteStore = store
                manager.setCurrentUserPermissions(DB_ACCESS_GROUP_MEMBERS, forStoreName: dbName as String, completionHander: { (success, error) -> Void in
                    if (error != nil) {
                        self.logger.logErrorWithMessages("Error setting permissions for user with error \(error)")
                    }
                    self.replicatorFactory = manager.replicatorFactory
                    if(encryptionEnabled){
                        self.pullReplication = manager.pullReplicationForStore(dbName, withEncryptionKeyProvider:keyProvider)
                        self.pushReplication = manager.pushReplicationForStore(dbName, withEncryptionKeyProvider:keyProvider)
                    }
                    else{
                        self.pullReplication = manager.pullReplicationForStore(dbName)
                        self.pushReplication = manager.pushReplicationForStore(dbName)
                        
                    }

                    self.pullItems()
                })
            }
            
        })
    }

    func listItems(cb:()->Void) {
       logger.logDebugWithMessages("listItems called")
            var query:CDTQuery
            query = CDTCloudantQuery(dataType: "TodoItem")
            self.datastore.performQuery(query, completionHandler: { (results, error) -> Void in
                if((error) != nil) {
                    self.logger.logErrorWithMessages("listItems failed with error \(error.description)")
                }
                else{
                    self.itemList = results as! [TodoItem]
                    self.reloadLocalTableData()
                }
                cb()
            })
    }
    
    func createItem(item: TodoItem) {
        self.datastore.save(item, completionHandler: { (object, error) -> Void in
            if(error != nil){
                self.logger.logErrorWithMessages("createItem failed with error \(error.description)")
            } else {
                self.listItems({ () -> Void in
                    self.logger.logInfoWithMessages("Item succesfuly created")
                })
            }
        })
    }
    
    func updateItem(item: TodoItem) {
        self.datastore.save(item, completionHandler: { (object, error) -> Void in
            if(error != nil){
                self.logger.logErrorWithMessages("updateItem failed with error \(error)")
            } else {
                self.listItems({ () -> Void in
                    self.logger.logInfoWithMessages("Item succesfuly update")
                })
            }
        })
    }
    
    func deleteItem(item: TodoItem) {
        self.datastore.delete(item, completionHandler: { (deletedObjectId, deletedRevisionId, error) -> Void in
            if(error != nil){
                self.logger.logErrorWithMessages("deleteItem failed with error \(error)")
            } else {
                self.listItems({ () -> Void in
                    self.logger.logInfoWithMessages("Item succesfuly deleted")
                })
            }
        })
    }
    
    // MARK: - Cloud Sync
    
    func pullItems() {
        var error:NSError?
        self.pullReplicator = self.replicatorFactory.oneWay(self.pullReplication, error: &error)
        if(error != nil){
            self.logger.logErrorWithMessages("Error creating oneWay pullReplicator \(error)")
        }
        
        self.pullReplicator.delegate = self
        self.doingPullReplication = true
        self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull Items from Cloudant")
        
        error = nil
        println("Replicating data with NoSQL Database on the cloud")
        self.pullReplicator.startWithError(&error)
        if(error != nil){
            self.logger.logErrorWithMessages("Error starting pullReplicator \(error)")
        }
    }
    
    func pushItems() {
        var error:NSError?
        self.pushReplicator = self.replicatorFactory.oneWay(self.pushReplication, error: &error)
        if(error != nil){
            self.logger.logErrorWithMessages("Error creating oneWay pullReplicator \(error)")
        }
        
        self.pushReplicator.delegate = self
        self.doingPullReplication = false
        self.refreshControl?.attributedTitle = NSAttributedString(string: "Pushing Items to Cloudant")
        
        error = nil
        self.pushReplicator.startWithError(&error)
        if(error != nil){
            self.logger.logErrorWithMessages("Error starting pushReplicator \(error)")
        }
        

    }
    
    // MARK: - CDTReplicator delegate methods
    
    /**
    * Called when the replicator changes state.
    */
    func replicatorDidChangeState(replicator: CDTReplicator!) {
        self.logger.logInfoWithMessages("replicatorDidChangeState \(CDTReplicator.stringForReplicatorState(replicator.state))")
    }
    
    /**
    * Called whenever the replicator changes progress
    */
    func replicatorDidChangeProgress(replicator: CDTReplicator!) {
    
        self.logger.logInfoWithMessages("replicatorDidChangeProgress \(CDTReplicator.stringForReplicatorState(replicator.state))")
    
    }
    
    /**
    * Called when a state transition to COMPLETE or STOPPED is
    * completed.
    */
    func replicatorDidComplete(replicator: CDTReplicator!) {
        
        self.logger.logInfoWithMessages("replicatorDidComplete \(CDTReplicator.stringForReplicatorState(replicator.state))")
        
        if self.doingPullReplication! {
            //done doing pull, lets start push
            self.pushItems()
        } else {
            //doing push, push is done read items from local data store and end the refresh UI
            self.listItems({ () -> Void in
                self.logger.logDebugWithMessages("Done refreshing table after replication")
                self.refreshControl?.attributedTitle = NSAttributedString(string: " ")
                self.refreshControl?.endRefreshing()
                self.settingsButton.enabled = true
            })
        }
    
    }
    
    /**
    * Called when a state transition to ERROR is completed.
    */
    
    func replicatorDidError(replicator: CDTReplicator!, info: NSError!) {
        self.refreshControl?.attributedTitle = NSAttributedString(string: "Error replicating with Cloudant")
        self.logger.logErrorWithMessages("replicatorDidError \(info)")
        self.listItems({ () -> Void in
            println("")
            self.refreshControl?.endRefreshing()
        })
    }

    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if section == 0 {
            return self.filteredListItems.count
        } else {
            return 1
        }
        
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("ItemCell", forIndexPath: indexPath) as! UITableViewCell
            let item = self.filteredListItems[indexPath.row] as TodoItem
            
            // Configure the cell
            cell.imageView?.image = self.getPriorityImage(item.priority.integerValue)
            let textField = cell.contentView.viewWithTag(3) as! UITextField
            textField.hidden = false
            textField.text = item.name as String
            cell.contentView.tag = 0
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("AddCell", forIndexPath: indexPath) as! UITableViewCell
            cell.contentView.tag = 1
            return cell
        }
        
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.section == 0
    }

    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            //Delete the row from the data source
            self.deleteItem(self.filteredListItems[indexPath.row])
            self.filteredListItems.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            self.changePriorityForCell(cell!)
        }
        
    }
    
    // MARK: - Handle Priority Indicators
    
    func changePriorityForCell(cell: UITableViewCell){
        let indexPath = self.tableView.indexPathForCell(cell)
        let item = self.filteredListItems[indexPath!.row] as TodoItem
        let selectedPriority = item.priority.integerValue
        let newPriority = self.getNextPriority(selectedPriority)
        item.priority = NSNumber(integer: newPriority)
        cell.imageView?.image = self.getPriorityImage(newPriority)
        self.updateItem(item)
    }
    
    func getNextPriority(currentPriority: Int) -> Int {
        
        var newPriority: Int
        
        switch currentPriority {
        case 2:
            newPriority = 0
        case 1:
            newPriority = 2
        default:
            newPriority = 1
        }
        return newPriority
    }
    
    func getPriorityImage (priority: Int) -> UIImage {
        
        var resultImage : UIImage
        
        switch priority {
        case 2:
            resultImage = self.highImage!
        case 1:
            resultImage = self.mediumImage!
        default:
            resultImage = self.lowImage!
        }
        return resultImage
    }
    
    func getPriorityForString(priorityString: String = "") -> Int {
        var priority : Int
        
        switch priorityString {
        case "All":
            priority = 0
        case "Medium":
            priority = 1
        case "High":
            priority = 2
        default:
            priority = 0
        }
        return priority
    }
    

    // MARK: Custom filtering
    
    func filterContentForPriority(scope: String = "All") {
        
        let priority = self.getPriorityForString(priorityString: scope)
        
        if(priority == 1 || priority == 2){
            self.filteredListItems = self.itemList.filter({ (item: TodoItem) -> Bool in
                if item.priority.integerValue == priority {
                    return true
                } else {
                    return false
                }
            })
        } else {
            //don't filter select all
            self.filteredListItems.removeAll(keepCapacity: false)
            self.filteredListItems = self.itemList
            
        }
    }
    
    @IBAction func filterTable(sender: UISegmentedControl){
        self.reloadLocalTableData()
    }
    
    // MARK: textField delegate functions
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.handleTextFields(textField)
        return true
    }
    
    func handleTextFields(textField: UITextField) {
        if textField.superview?.tag == 1 && textField.text.isEmpty == false {
            self.addItemFromtextField(textField)
        } else {
            self.updateItemFromtextField(textField)
        }
        textField.resignFirstResponder()
    }
    
    func updateItemFromtextField(textField: UITextField) {
        let cell = textField.superview?.superview as! UITableViewCell
        let indexPath = self.tableView.indexPathForCell(cell)
        var item = self.filteredListItems[indexPath!.row]
        item.name = textField.text
        self.updateItem(item)
    }
    func addItemFromtextField(textField: UITextField) {
        let priority = self.getPriorityForString(priorityString: self.segmentFilter.titleForSegmentAtIndex(self.segmentFilter.selectedSegmentIndex)!)
        let name = textField.text
        var item = TodoItem()
        item.name = textField.text
        item.priority = NSNumber(integer: priority)
        self.createItem(item)
        textField.text = ""
    }
    
    func reloadLocalTableData() {
        self.filterContentForPriority(scope: self.segmentFilter.titleForSegmentAtIndex(self.segmentFilter.selectedSegmentIndex)!)
        self.filteredListItems.sort { (item1: TodoItem, item2: TodoItem) -> Bool in
            return item1.name.localizedCaseInsensitiveCompare(item2.name as String) == .OrderedAscending
        }
        if self.tableView != nil {
            self.tableView.reloadData()
        }
    }
    
    func handleRefreshAction()
    {
        if (IBM_SYNC_ENABLE) {
            self.pullItems()
        } else {
            self.listItems({ () -> Void in
                self.logger.logDebugWithMessages("Done refreshing table in handleRefreshAction")
                self.refreshControl?.endRefreshing()
            })
        }
    }
}

