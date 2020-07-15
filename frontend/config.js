var util = require('util');
var path = require('path');
var hfc = require('fabric-client');

// indicate to the application where the setup file is located so it able
// to have the hfc load it to initalize the fabric client instance
hfc.setConfigSetting('network-connection-profile-path',path.join(__dirname, 'artifacts', 'network-config.yaml'));
    hfc.setConfigSetting('TradeFloor-connection-profile-path',path.join(__dirname, 'artifacts', 'tradefloor.yaml'));
hfc.setConfigSetting('Acme-connection-profile-path',path.join(__dirname, 'artifacts', 'acme.yaml'));
// some other settings the application might need to know
hfc.addConfigFile(path.join(__dirname, 'config.json'));
