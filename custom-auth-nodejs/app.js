/*
 * Licensed Materials - Property of IBM
 * 5725-I43 (C) Copyright IBM Corp. 2014. All Rights Reserved.
 * US Government Users Restricted Rights - Use, duplication or
 * disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

var express = require('express'),
    passport = require('passport'),
    ImfBackendStrategy = require('passport-imf-token-validation').ImfBackendStrategy,
    customRealm = 'customAuthRealm_1';
    

passport.use(new ImfBackendStrategy());

// setup middleware
var app = express();

app.use(passport.initialize());
app.use(express.bodyParser());
app.use(app.router);
app.use(express.errorHandler());

app.post('/apps/:tenantID/'+customRealm+'/startAuthorization',
    passport.authenticate('imf-backend-strategy', {session: false}),
    function(req, res) {
        console.log ("tenantID " + req.param("tenantID"));
        var returnedJSON = startAuthorization(req.body.headers);
        res.json(returnedJSON);
    });

app.post('/apps/:tenantID/'+customRealm+'/handleChallengeAnswer',
    passport.authenticate('imf-backend-strategy', {session: false}),
    function(req, res) {
        console.log ("tenantID " + req.param("tenantID"));
        var returnedJSON = handleChallengeAnswer(req.body.headers, req.body.stateId, req.body.challengeAnswer);
        res.json(returnedJSON);
    });

var users = {
    "john": {
        password: "123",
        displayName: "John Lennon"
    },
    "paul": {
        password: "456",
        displayName: "Paul McCartney"
    }
};

var startAuthorization = function(headers) {
    return {
        status: "challenge",
        challenge: {
            message: "wrong_credentials"
        }, stateId : "myStateId"
    };
};

var handleChallengeAnswer = function(headers, stateId, challengeAnswer) {
    console.log('State id ' + stateId);
    if (challengeAnswer && users[challengeAnswer.userName] && challengeAnswer.password === users[challengeAnswer.userName].password) {
        return {
            status: "success",
            userIdentity: {
                userName: challengeAnswer.userName,
                displayName: users[challengeAnswer.userName].displayName
            }
        };
    } else {
        return {
            status: "challenge",
            challenge: {
                message: "wrong_credentials"
            }
        }
    }
};

// There are many useful environment variables available in process.env.
// VCAP_APPLICATION contains useful information about a deployed application.
var appInfo = JSON.parse(process.env.VCAP_APPLICATION || "{}");
// TODO: Get application information and use it in your app.

// VCAP_SERVICES contains all the credentials of services bound to
// this application. For details of its content, please refer to
// the document or sample of each service.
var services = JSON.parse(process.env.VCAP_SERVICES || "{}");
// TODO: Get service credentials and communicate with bluemix services.

// The IP address of the Cloud Foundry DEA (Droplet Execution Agent) that hosts this application:
var host = (process.env.VCAP_APP_HOST || 'localhost');
// The port on the DEA for communication with the application:
var port = (process.env.VCAP_APP_PORT || 3001);
// Start server
app.listen(port, host);
console.log('Custom authentication App started on port ' + port);
