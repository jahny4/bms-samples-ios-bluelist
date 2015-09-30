/*
 * IBM Confidential OCO Source Materials
 *
 * 5725-I43 Copyright IBM Corp. 2015
 *
 * The source code for this program is not published or otherwise
 * divested of its trade secrets, irrespective of what has
 * been deposited with the U.S. Copyright Office.
 *
*/

// External dependencies
var crypto = require('crypto');

// Internal dependencies

/*
 * Create the BlueList sample database:
 *  - create database with the given name
 *  - create data type views
 */
function createDatabase(adminCredentials, databaseName, callback) {
    console.log('#node: createDatabase()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);

    // Create the database
    console.log("createDatabase: Creating database: " + databaseName);
    cloudant.db.create(databaseName, function(err, body) {

        // Handle request error
        if (err) { 

	        // Database/views already exists; invoke callback
	        if (err.statusCode === 412) {
        		console.log("createDatabase: Database ("+databaseName+") already created.");
	            callback(null);
	        }

	        // Error creating database
	        else {
	        	console.log("createDatabase: Failed to create database ("+databaseName+"); error = " + err.message);
		        err = new Error("Failed to create database "+databaseName+"; error = "+JSON.stringify(err)+".");
	            callback(err);
	        }
        }

        // Database created successfully, create views
        else {
      		console.log("createDatabase: Database ("+databaseName+") created successfully.");
            addListDataTypesView(adminCredentials, databaseName, callback);
        }
    	
    });

}

/*
 * Delete BlueList sample database.
 */
function deleteDatabase(adminCredentials, databaseName, callback) {
    console.log('#node: deleteDatabase()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);

    // Delete the database
    console.log("deleteDatabase: Creating database: " + databaseName);
    cloudant.db.destroy(databaseName, function(err, body) {

        // Handle request error
        if (err) { 

	        // Database does not exist; invoke callback
	        if (err.statusCode === 404) {
        		console.log("deleteDatabase: Database ("+databaseName+") does not exist; nothing more to do.");
	            callback(null);
	        }

	        // Error deleting database
	        else {
	        	console.log("deleteDatabase: Failed to delete database ("+databaseName+"); error = " + err.message);
		        err = new Error("Failed to delete database "+databaseName+"; error = "+JSON.stringify(err)+".");
	            callback(err);
	        }
        }

        // Database deleted successfully
        else {
        	console.log("deleteDatabase: Database ("+databaseName+") deleted successfully.");
	  		callback(null);
        }
    	
    });

}

/*
 * Create list dataTypes view.
 */
function addListDataTypesView(adminCredentials, databaseName, callback) {
	console.log('#addListDataTypesView()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);
    var db = cloudant.use(databaseName);

    var viewContent = {
	  		"views": {
	    		"listdatatypes": {
	      			"map": "function(doc) {\n    if (doc[\"@datatype\"]) {\n        emit(doc[\"@datatype\"], 1);\n    }\n}",
	      			"reduce": "_count"
	    		}
	  		}
		};
    var viewName = "_design/_imfdata_listdatatypes";

    // Create the view
    console.log("addListDataTypesView: Creating view: " + viewName);
    db.insert(viewContent, viewName, function(err, body) {

        // Handle request error
        if (err) { 

	        // Error creating view
        	console.log("addListDataTypesView: Failed to create listdatatypes view for database ("+databaseName+"); error = " + err.message);
	        err = new Error("Created database "+databaseName+" but failed to create listdatatypes view; error = "+JSON.stringify(err)+".");
			callback(err);

        }

        // View created successfully, create next view
        else {
            console.log("addListDataTypesView: listdatatypes view for database ("+databaseName+") created successfully.");
			addKeyCountTypedView(adminCredentials, databaseName, callback);
        }
    	
    });
}

/*
 * Create key count typed view.
 */
function addKeyCountTypedView(adminCredentials, databaseName, callback) {
	console.log('#addKeyCountTypedView()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);
    var db = cloudant.use(databaseName);

    var viewContent = {
	  		"views": {
	    		"keyCountTyped": {
	      			"map": "function(doc) {\n    if (!doc.hasOwnProperty(\"@datatype\")) {\n        return;\n    }\n    var keys = Object.keys(doc);\n    for (var k in keys) {\n        key = keys[k];\n        if ([\"_id\", \"_rev\", \"@datatype\"].indexOf(key) == -1) {\n            emit([doc[\"@datatype\"], key], 1);\n        }\n    }\n}",
	      			"reduce": "_count"
	    		}
	  		}
		};
    var viewName = "_design/_imfdata_keycounttyped";

    // Create the view
    console.log("addKeyCountTypedView: Creating view: " + viewName);
    db.insert(viewContent, viewName, function(err, body) {

        // Handle request error
        if (err) { 

	        // Error creating view
        	console.log("addKeyCountTypedView: Failed to create keyCountTyped view for database ("+databaseName+"); error = " + err.message);
	        err = new Error("Created database "+databaseName+" but failed to create keyCountTyped view; error = "+JSON.stringify(err)+".");
			callback(err);

        }

        // View created successfully, create next view
        else {
            console.log("addKeyCountTypedView: keyCountTyped view for database ("+databaseName+") created successfully.");
			addKeyCountUntypedView(adminCredentials, databaseName, callback);
        }
    	
    });

}

/*
 * Create key count untyped view.
 */
function addKeyCountUntypedView(adminCredentials, databaseName, callback) {
	console.log('#addKeyCountUntypedView()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);
    var db = cloudant.use(databaseName);

    var viewContent = {
	  		"views": {
	    		"keyCountUntyped": {
	      			"map": "function(doc) {\n    var keys = Object.keys(doc);\n    for (var k in keys) {\n        key = keys[k];\n        if ([\"_id\", \"_rev\", \"@datatype\"].indexOf(key) == -1) {\n            emit(key, 1);\n        }\n    }\n}",
	      			"reduce": "_count"
	    		}
	  		}
		};
    var viewName = "_design/_imfdata_keycountuntyped";

    // Create the view
    console.log("addKeyCountUntypedView: Creating view: " + viewName);
    db.insert(viewContent, viewName, function(err, body) {

        // Handle request error
        if (err) { 

	        // Error creating view
        	console.log("addKeyCountUntypedView: Failed to create keyCountUntyped view for database ("+databaseName+"); error = " + err.message);
	        err = new Error("Created database "+databaseName+" but failed to create keyCountUntyped view; error = "+JSON.stringify(err)+".");
	  		callback(err);

        }

        // View created successfully, create index
        else {
            console.log("addKeyCountUntypedView: keyCountUntyped view for database ("+databaseName+") created successfully.");
	  		addCloudantQueryDataTypesIndex(adminCredentials, databaseName, callback);
        }
    	
    });

}

/*
 * Create cloudant query @datatypes index.
 */
function addCloudantQueryDataTypesIndex(adminCredentials, databaseName, callback) {
	console.log('#addCloudantQueryDataTypesIndex()');

    var cloudant = require('cloudant')(adminCredentials.protocol + '://' + adminCredentials.auth + '@' + adminCredentials.host + ':' + adminCredentials.port);
    var db = cloudant.use(databaseName);

    var indexContent = {
	  		index: {
	    		fields: ['@datatype']
	  		},
	  		ddoc: '_imfdata_defaultdatatype'
		};
	var indexName = "_design/_imfdata_defaultdatatype";

    // Create the view
    console.log("addCloudantQueryDataTypesIndex: Creating index: " + indexName);
    db.index(indexContent, function(err, body) {

        // Handle request error
        if (err) { 

	        // Error creating index
        	console.log("addCloudantQueryDataTypesIndex: Failed to create @datatype index for database ("+databaseName+"); error = " + err.message);
	        err = new Error("Created database "+databaseName+" but failed to create index '@datatype'; error = "+JSON.stringify(err)+".");
	  		callback(err);

        }

        // Index created successfully, invoke callback
        else {
            console.log("addCloudantQueryDataTypesIndex: @datatype index for database ("+databaseName+") created successfully.");
	  		callback(null);
        }
    	
    });

}

/*
 * Build a bluelist sample database name for the given user.
 * The first part of the name is 'todosdb'.
 * The second part of the name is generated based on the user name using SHA1.
 */
function getDatabaseName(userName, callback) {
    console.log('#node: getDatabaseName()');

    var databaseName = 'todosdb';
    var SHA1 = crypto.createHash('sha1');
    SHA1.update(userName);
    databaseName += ( '_' + SHA1.digest('hex') );
    console.log("node: getDatabaseName: User ("+userName+"); database name = " + databaseName);
    callback(null, databaseName);
}

exports.createDatabase = createDatabase;
exports.deleteDatabase = deleteDatabase;
exports.getDatabaseName = getDatabaseName;
