/**
 * Copyright 2017 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
const { FileSystemWallet, Gateway } = require('fabric-network');

var util = require('util');
var helper = require('./helper.js');
var logger = helper.getLogger('Query');

const wallet = new FileSystemWallet('./fabric-client-kv-acme');


var queryChaincode = async function(peer, channelName, chaincodeName, fcn, username, org_name) {
	let client = null;
	let gateway = null;
	try {
		// first setup the client for this org
		client = await helper.getClientForOrg(org_name, username);
		gateway = new Gateway();
		let connectionOptions = {
			identity: username,
			wallet: wallet,
			discovery: { enabled:false, asLocalhost: true }
		};
		await gateway.connect(client, connectionOptions);
		const network = await gateway.getNetwork(channelName);
		logger.debug('Successfully got the fabric client for the organization "%s"', org_name);
		const contract = network.getContract(chaincodeName);
		let results = await contract.evaluateTransaction(fcn);
		return results;
	} catch(error) {
		logger.error('Failed to query due to error: ' + error.stack ? error.stack : error);
		return error.toString();
	} finally {
		if (gateway) {
			gateway.disconnect();
		}
	}
};

exports.queryChaincode = queryChaincode;