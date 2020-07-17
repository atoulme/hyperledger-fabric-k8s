/**
 * Copyright 2017 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an 'AS IS' BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
'use strict';
var log4js = require('log4js');
var logger = log4js.getLogger('frontend');
var express = require('express');
var session = require('express-session');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var http = require('http');
var util = require('util');
var app = express();
var expressJWT = require('express-jwt');
var jwt = require('jsonwebtoken');
var bearerToken = require('express-bearer-token');
var cors = require('cors');
const tracer = require('signalfx-tracing').init({
	// Service name, also configurable via
	// SIGNALFX_SERVICE_NAME environment variable
	service: 'auction-app',
	// Smart Agent or Gateway endpoint, also configurable via
	// SIGNALFX_ENDPOINT_URL environment variable
	url: 'http://signalfx-agent:9080/v1/trace', // http://localhost:9080/v1/trace by default
	// Optional environment tag
	tags: {environment: 'hlf-k8s'}
});

require('./config.js');
var hfc = require('fabric-client');

var helper = require('./app/helper.js');
var invoke = require('./app/invoke-transaction.js');
var runTx = require('./app/run-tx.js');
var query = require('./app/query.js');
var host = process.env.HOST || hfc.getConfigSetting('host');
var port = process.env.PORT || hfc.getConfigSetting('port');
///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SET CONFIGURATONS ////////////////////////////
///////////////////////////////////////////////////////////////////////////////
app.options('*', cors());
app.use(cors());
//support parsing of application/json type post data
app.use(bodyParser.json());
//support parsing of application/x-www-form-urlencoded post data
app.use(bodyParser.urlencoded({
	extended: false
}));
// set secret variable
app.set('secret', 'thisismysecret');
// app.use(expressJWT({
// 	secret: 'thisismysecret'
// }).unless({
// 	path: ['/users']
// }));
//app.use(bearerToken());
// app.use(function(req, res, next) {
// 	logger.debug(' ------>>>>>> new request for %s',req.originalUrl);
// 	if (req.originalUrl.indexOf('/users') >= 0) {
// 		return next();
// 	}
//
// 	var token = req.token;
// 	jwt.verify(token, app.get('secret'), function(err, decoded) {
// 		if (err) {
// 			res.send({
// 				success: false,
// 				message: 'Failed to authenticate token. Make sure to include the ' +
// 					'token returned from /users call in the authorization header ' +
// 					' as a Bearer token'
// 			});
// 			return;
// 		} else {
// 			// add the decoded user name and org name to the request object
// 			// for the downstream code to use
// 			req.username = decoded.username;
// 			req.orgname = decoded.orgName;
// 			logger.debug(util.format('Decoded from JWT token: username - %s, orgname - %s', decoded.username, decoded.orgName));
// 			return next();
// 		}
// 	});
// });

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// START SERVER /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
process.on('uncaughtException', function(ex) {
	logger.error("Uncaught exception", ex);
});
var server = http.createServer(app).listen(port, function() {});
logger.info('****************** SERVER STARTED ************************');
logger.info('***************  http://%s:%s  ******************',host,port);
const terminationFn = () => {
	console.log('Closing http server.');
	server.close(() => {
		console.log('Http server closed.');
	});
};
process.on('SIGTERM', terminationFn);
process.on('SIGINT', terminationFn);
server.timeout = 240000;

function getErrorMessage(field) {
	var response = {
		success: false,
		message: field + ' field is missing or Invalid in the request'
	};
	return response;
}

// Serve static files:
app.use(express.static('/public'));
///////////////////////////////////////////////////////////////////////////////
///////////////////////// REST ENDPOINTS START HERE ///////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Register and enroll user
app.post('/users', async function(req, res) {
	var username = req.body.username;
	var orgName = req.body.orgName;
	logger.debug('End point : /users');
	logger.debug('User name : ' + username);
	logger.debug('Org name  : ' + orgName);
	if (!username) {
		res.json(getErrorMessage('\'username\''));
		return;
	}
	if (!orgName) {
		res.json(getErrorMessage('\'orgName\''));
		return;
	}
	var token = jwt.sign({
		exp: Math.floor(Date.now() / 1000) + parseInt(hfc.getConfigSetting('jwt_expiretime')),
		username: username,
		orgName: orgName
	}, app.get('secret'));
	let response = await helper.getRegisteredUser(username, orgName, true);
	logger.debug('-- returned from registering the username %s for organization %s',username,orgName);
	if (response && typeof response !== 'string') {
		logger.debug('Successfully registered the username %s for organization %s',username,orgName);
		response.token = token;
		res.json(response);
	} else {
		logger.debug('Failed to register the username %s for organization %s with::%s',username,orgName,response);
		res.json({success: false, message: response});
	}

});


// Invoke transaction on chaincode on target peers
app.post('/channels/:channelName/chaincodes/:chaincodeName/:orgname/:username', async function(req, res) {
	logger.debug('==================== INVOKE ON CHAINCODE ==================');
	var peers = req.body.peers;
	var chaincodeName = req.params.chaincodeName;
	var channelName = req.params.channelName;
	var orgname = req.params.orgname;
	var username = req.params.username;
	var fcn = req.body.fcn;
	var args = req.body.args;
	logger.debug('channelName  : ' + channelName);
	logger.debug('chaincodeName : ' + chaincodeName);
	logger.debug('fcn  : ' + fcn);
	logger.debug('args  : ' + args);
	if (!chaincodeName) {
		res.json(getErrorMessage('\'chaincodeName\''));
		return;
	}
	if (!channelName) {
		res.json(getErrorMessage('\'channelName\''));
		return;
	}
	if (!fcn) {
		res.json(getErrorMessage('\'fcn\''));
		return;
	}
	if (!args) {
		res.json(getErrorMessage('\'args\''));
		return;
	}

	try {
		let message = await invoke.invokeChaincode(peers, channelName, chaincodeName, fcn, args, username, orgname);
		res.send(message);
	} catch(ex) {
		res.json({success: false, message: ex.message});
	}
});

// Query on chaincode on target peers
app.get('/channels/:channelName/chaincodes/:chaincodeName', async function(req, res) {
	logger.debug('==================== QUERY BY CHAINCODE ==================');
	var channelName = req.params.channelName;
	var chaincodeName = req.params.chaincodeName;
	let fcn = req.query.fcn;

	logger.debug('channelName : ' + channelName);
	logger.debug('chaincodeName : ' + chaincodeName);
	logger.debug('fcn : ' + fcn);

	if (!chaincodeName) {
		res.json(getErrorMessage('\'chaincodeName\''));
		return;
	}
	if (!channelName) {
		res.json(getErrorMessage('\'channelName\''));
		return;
	}
	if (!fcn) {
		res.json(getErrorMessage('\'fcn\''));
		return;
	}

	let message = await query.queryChaincode(channelName, chaincodeName, fcn);
	res.send(message);
});

function generateID() {
	return Math.random().toString(36).substr(2);
}

async function generateBid(auctionId, value, parentSpan) {

	var chaincodeName = "splunk_cc";
	var channelName = "poc-bids";
	var fcn = "createBid";
	const bidId = generateID();
	const span = tracer.startSpan("createBid", {childOf: parentSpan, tags : {"span.kind": "server", "bidId": bidId, "auctionId": auctionId}});
	var args = [bidId, value, auctionId, auctionId];
	logger.debug('channelName  : ' + channelName);
	logger.debug('chaincodeName : ' + chaincodeName);
	logger.debug('fcn  : ' + fcn);
	logger.debug('args  : ' + args);

	let message = await runTx.runTx(channelName, chaincodeName, fcn, args);
	span.finish();
	return message;
}

async function generateAuction(auctionId, auctionName) {
	var chaincodeName = "splunk_cc";
	var channelName = "poc-bids";
	var fcn = "createAuction";
	var args = [auctionId, auctionName];
	logger.debug('channelName  : ' + channelName);
	logger.debug('chaincodeName : ' + chaincodeName);
	logger.debug('fcn  : ' + fcn);
	logger.debug('args  : ' + args);

	let message = await runTx.runTx(channelName, chaincodeName, fcn, args);
	return message;
}

async function generateAuctionAndBids(auctionName) {
	const auctionId = generateID();
	const span = tracer.startSpan(auctionName, {tags: {"environment": "hyperledger-demo", "span.kind": "server", "auctionId": auctionId}});
	logger.debug('==================== GENERATE AUCTION AND BIDS ==================');
	generateAuction(auctionId, auctionName);
	for (let i = 0; i < 100; i++) {
		generateBid(auctionId, (10 * i).toString(), span);
	}
	span.finish();
}

function sleep(ms) {
	return new Promise(resolve => setTimeout(resolve, ms));
}

async function scheduleAuctionAndBids(auctionBaseName, counter) {
	await generateAuctionAndBids(auctionBaseName + ' ' + ++counter);
	await sleep(30000);
	if (generatorOn) {
		scheduleAuctionAndBids(auctionBaseName, counter);
	}
}

app.get('/generateAuctionAndBids', async function(req, res) {
    const result = await generateAuctionAndBids("sample");
    res.send(result);
});

var generatorOn = false;

app.get('/startBidBot', async function(req, res) {
	logger.debug('==================== START BID BOT ==================');
	if (!generatorOn) {
		generatorOn = true;
		res.end('OK', () => scheduleAuctionAndBids("Bot auction", 0));
	} else {
		res.send('Already started');
	}

});

app.get('/stopBidBot', async function(req, res) {
	logger.debug('==================== STOP BID BOT ==================');
	generatorOn = false;
	res.send("OK");
});