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

    let DATATYPE_FIELD = "@datatype"
    let DATATYPE_VALUE = "TodoItem"
    
    let NAME_FIELD = "name"
    let PRIORITY_FIELD = "priority"
    
    //Priority Images
    var highImage   = UIImage(named: "priorityHigh.png")
    var mediumImage = UIImage(named: "priorityMedium.png")
    var lowImage    = UIImage(named: "priorityLow.png")
    
    @IBOutlet var segmentFilter: UISegmentedControl!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    //Intialize some list items
    var itemList: [CDTDocumentRevision] = []
    var filteredListItems = [CDTDocumentRevision]()
    
    var idTracker = 0

    // Cloud sync properties
    var dbName:String!
    var datastore: CDTDatastore!
    var datastoreManager:CDTDatastoreManager!
    var remotedatastoreurl: NSURL!
    var cloudantHttpInterceptor:CDTHTTPInterceptor!
    
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
        self.setupIMFDatabase()
        
        //Logging
        self.logger.logInfoWithMessages("this is a info test log in ListTableViewController:viewDidLoad")
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: - Data Management
    
    func setupIMFDatabase() {
        var error:NSError?
        var encryptionEnabled:Bool = false
        let configurationPath = NSBundle.mainBundle().pathForResource("bluelist", ofType: "plist")
        let configuration = NSDictionary(contentsOfFile: configurationPath!)
        let encryptionPassword = configuration?["encryptionPassword"] as! String
        if(encryptionPassword.isEmpty){
            encryptionEnabled = false
        }
        else {
            encryptionEnabled = true
            self.dbName = self.dbName + "secure"
        }
        
        // Create DatastoreManager
        let fileManager = NSFileManager()

        let documentDir = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last
        let storeUrl = documentDir?.URLByAppendingPathComponent("bluelistdir", isDirectory: true)
        
        let exists = fileManager.fileExistsAtPath((storeUrl?.path)!)
        
        if(!exists){
            do{
                try fileManager.createDirectoryAtURL(storeUrl!, withIntermediateDirectories: true, attributes: nil)
            }catch let error as NSError{
                let alert:UIAlertView = UIAlertView(title: "Error", message: "Could not create CDTDatastoreManager with directory \(storeUrl?.absoluteString).  Error: \(error)", delegate:self , cancelButtonTitle: "Okay")
                alert.show()
                return
            }
        }

        do{
            self.datastoreManager = try CDTDatastoreManager(directory: storeUrl?.path)
        }catch let error as NSError{
            let alert:UIAlertView = UIAlertView(title: "Error", message: "Could not create CDTDatastoreManager with directory \(storeUrl?.absoluteString).  Error: \(error)", delegate:self , cancelButtonTitle: "Okay")
            alert.show()
            return
        }
        
        //CDTEncryptionKeyProvider used for encrypting local datastore
        var keyProvider:CDTEncryptionKeyProvider!

        //create a local data store. Encrypt the local store if the setting is enabled
        if(encryptionEnabled){
            //Initialize the key provider
            keyProvider = CDTEncryptionKeychainProvider(password: encryptionPassword, forIdentifier:"bluelist")
            NSLog("%@", "Attempting to create an encrypted local data store")
            do {
                //Initialize the encrypted store
                self.datastore = try self.datastoreManager.datastoreNamed(self.dbName, withEncryptionKeyProvider: keyProvider)
            } catch let error1 as NSError {
                error = error1
                self.datastore = nil
            }
        }
        else{
            NSLog("%@","Attempting to create a local data store")
            do {
                self.datastore = try self.datastoreManager.datastoreNamed(self.dbName)
            } catch let error1 as NSError {
                error = error1
                self.datastore = nil
            }
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
        
        // Setup required indexes for Query
        self.datastore.ensureIndexed([DATATYPE_FIELD], withName: "datatypeindex")
        
        if (!IBM_SYNC_ENABLE) {
            self.listItems({ () -> Void in
                self.logger.logDebugWithMessages("Done refreshing we are not using cloud")
                self.refreshControl?.endRefreshing()
            })
            return
        }
        self.replicatorFactory = CDTReplicatorFactory(datastoreManager: self.datastoreManager)
        
        self.pullReplication = CDTPullReplication(source: self.remotedatastoreurl, target: self.datastore)
        self.pullReplication.addInterceptor(self.cloudantHttpInterceptor)
        
        self.pushReplication = CDTPushReplication(source: self.datastore, target: self.remotedatastoreurl)
        self.pushReplication.addInterceptor(self.cloudantHttpInterceptor)
        
        self.pullItems()
    }

    func listItems(cb:()->Void) {
       logger.logDebugWithMessages("listItems called")
        let resultSet:CDTQResultSet = self.datastore.find([DATATYPE_FIELD : DATATYPE_VALUE])
        var results:[CDTDocumentRevision] = Array()
        
        resultSet.enumerateObjectsUsingBlock { (rev, idx, stop) -> Void in
            results.append(rev)
        }
        
        self.itemList = results
        self.reloadLocalTableData()
        cb()
    }
    
    func createItem(item: CDTMutableDocumentRevision) {
        do{
            try self.datastore.createDocumentFromRevision(item)
            self.listItems({ () -> Void in
                self.logger.logInfoWithMessages("Item succesfuly created")
            })
        }catch let error as NSError{
            self.logger.logErrorWithMessages("createItem failed with error \(error.description)")
        }
    }
    
    func updateItem(item: CDTMutableDocumentRevision) {
        do{
            try self.datastore.updateDocumentFromRevision(item)
            self.listItems({ () -> Void in
                self.logger.logInfoWithMessages("Item successfully updated")
            })
        }catch let error as NSError{
            self.logger.logErrorWithMessages("updateItem failed with error \(error.description)")
        }
    }
    
    func deleteItem(item: CDTDocumentRevision) {
        do{
            try self.datastore.deleteDocumentFromRevision(item)
            self.listItems({ () -> Void in
                self.logger.logInfoWithMessages("Item successfully deleted")
            })
        }catch let error as NSError{
            self.logger.logErrorWithMessages("deleteItem failed with error \(error)")
        }
    }
    
    // MARK: - Cloud Sync
    
    func pullItems() {
        var error:NSError?
        do {
            self.pullReplicator = try self.replicatorFactory.oneWay(self.pullReplication)
        } catch let error1 as NSError {
            error = error1
            self.pullReplicator = nil
        }
        if(error != nil){
            self.logger.logErrorWithMessages("Error creating oneWay pullReplicator \(error)")
        }
        
        self.pullReplicator.delegate = self
        self.doingPullReplication = true
        self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull Items from Cloudant")
        
        error = nil
        print("Replicating data with NoSQL Database on the cloud")
        do {
            try self.pullReplicator.start()
        } catch let error1 as NSError {
            error = error1
        }
        if(error != nil){
            self.logger.logErrorWithMessages("Error starting pullReplicator \(error)")
        }
    }
    
    func pushItems() {
        var error:NSError?
        do {
            self.pushReplicator = try self.replicatorFactory.oneWay(self.pushReplication)
        } catch let error1 as NSError {
            error = error1
            self.pushReplicator = nil
        }
        if(error != nil){
            self.logger.logErrorWithMessages("Error creating oneWay pullReplicator \(error)")
        }
        
        self.pushReplicator.delegate = self
        self.doingPullReplication = false
        
        //update UI in main thread
        dispatch_async(dispatch_get_main_queue()) {
            self.refreshControl?.attributedTitle = NSAttributedString(string: "Pushing Items to Cloudant")
        }
            
        error = nil
        do {
            try self.pushReplicator.start()
        } catch let error1 as NSError {
            error = error1
        }
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
                
                //update UI in main thread
                dispatch_async(dispatch_get_main_queue()) {
                    self.refreshControl?.attributedTitle = NSAttributedString(string: " ")
                    self.refreshControl?.endRefreshing()
                    self.settingsButton.enabled = true
                }
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
            print("")
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
            let cell = tableView.dequeueReusableCellWithIdentifier("ItemCell", forIndexPath: indexPath) 
            let item = self.filteredListItems[indexPath.row] as CDTDocumentRevision
            
            // Configure the cell
            cell.imageView?.image = self.getPriorityImage(item.body()[PRIORITY_FIELD]!.integerValue)
            let textField = cell.contentView.viewWithTag(3) as! UITextField
            textField.hidden = false
            textField.text = item.body()[NAME_FIELD]! as? String
            cell.contentView.tag = 0
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("AddCell", forIndexPath: indexPath) 
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
        let item = (self.filteredListItems[indexPath!.row] as CDTDocumentRevision).mutableCopy()
        let selectedPriority = item.body()[PRIORITY_FIELD]!.integerValue
        let newPriority = self.getNextPriority(selectedPriority)
        item.body()[PRIORITY_FIELD] = NSNumber(integer: newPriority)
        
        //update UI in main thread
        dispatch_async(dispatch_get_main_queue()) {
            cell.imageView?.image = self.getPriorityImage(newPriority)
            self.updateItem(item)
        }
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
        
        let priority = self.getPriorityForString(scope)
        
        if(priority == 1 || priority == 2){
            self.filteredListItems = self.itemList.filter({ (item: CDTDocumentRevision) -> Bool in
                if item.body()[PRIORITY_FIELD]!.integerValue == priority {
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
        if textField.superview?.tag == 1 && textField.text!.isEmpty == false {
            self.addItemFromtextField(textField)
        } else {
            self.updateItemFromtextField(textField)
        }
        textField.resignFirstResponder()
    }
    
    func updateItemFromtextField(textField: UITextField) {
        let cell = textField.superview?.superview as! UITableViewCell
        let indexPath = self.tableView.indexPathForCell(cell)
        let item = self.filteredListItems[indexPath!.row].mutableCopy()
        item.body()[NAME_FIELD] = textField.text!
        self.updateItem(item)
    }
    func addItemFromtextField(textField: UITextField) {
        let priority = self.getPriorityForString(self.segmentFilter.titleForSegmentAtIndex(self.segmentFilter.selectedSegmentIndex)!)
        let name = textField.text
        let item = CDTMutableDocumentRevision()
        item.setBody([DATATYPE_FIELD : DATATYPE_VALUE, NAME_FIELD : name!, PRIORITY_FIELD : NSNumber(integer: priority)])
        
        self.createItem(item)
        textField.text = ""
    }
    
    func reloadLocalTableData() {
        self.filterContentForPriority(self.segmentFilter.titleForSegmentAtIndex(self.segmentFilter.selectedSegmentIndex)!)
        self.filteredListItems.sortInPlace { (item1: CDTDocumentRevision, item2: CDTDocumentRevision) -> Bool in
            return item1.body()[NAME_FIELD]!.localizedCaseInsensitiveCompare(item2.body()[NAME_FIELD]! as! String) == .OrderedAscending
        }
        if self.tableView != nil {
            dispatch_async(dispatch_get_main_queue()) {
                self.tableView.reloadData()
            }
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

