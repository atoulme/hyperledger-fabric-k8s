
VERSION=$1
CHAINCODE_PATH=$2
export FABRIC_CFG_PATH=/hlf_config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/hlf_config/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp/tlscacerts/cert.pem
export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/clearinghouse.example.com/users/Admin\@clearinghouse.example.com/msp


function installChaincodeJava() {
	PEER_NAME=$1
	CHAINCODE_NAME=$2
	MSP_ID=$3
	VERSION=$4
	ORG_NAME=$( echo $PEER_NAME | cut -d. -f1 --complement)

	mkdir -p $GOPATH/src/chaincode
    tar -xf /chaincode/contractbid/contractbid.tar -C $GOPATH/src/chaincode
  cd $GOPATH/src/chaincode/contractbid/

	echo "========== Installing chaincode [${CHAINCODE_NAME}] on ${PEER_NAME} =========="
	export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME/msp
	export CORE_PEER_ADDRESS=$PEER_NAME:7051
	export CORE_PEER_LOCALMSPID="$MSP_ID"
	export CORE_PEER_TLS_ROOTCERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/ca.crt
	export CORE_PEER_TLS_KEY_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.key
	export CORE_PEER_TLS_CERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.crt
	peer chaincode install -l java -n $CHAINCODE_NAME -v $VERSION -p $GOPATH/src/chaincode/contractbid/
}

function upgradeChaincode() {
	PEER_NAME=$1
	CHANNEL_NAME=$2
	CHAINCODE_NAME=$3
	MSP_ID=$4
	VERSION=$5

	ORG_NAME=$( echo $PEER_NAME | cut -d. -f1 --complement)

	echo "========== Upgrading chaincode [${CHAINCODE_NAME}] on ${PEER_NAME} in ${CHANNEL_NAME} =========="
	export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME/msp
	export CORE_PEER_ADDRESS=$PEER_NAME:7051
	export CORE_PEER_LOCALMSPID="$MSP_ID"
	export CORE_PEER_TLS_ROOTCERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/ca.crt
	export CORE_PEER_TLS_KEY_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.key
	export CORE_PEER_TLS_CERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.crt
	peer chaincode upgrade -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED \
		--cafile $ORDERER_CA \
		-C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args": []}' \
		-v $VERSION -P "OR ('ClearinghouseMSP.member','ManufacturerMSP.member')"
}



# Install chaincode onto peers. Do not worry about channels here.
installChaincodeJava "peer0.clearinghouse.example.com" "splunk_cc" "ClearinghouseMSP" $VERSION $CHAINCODE_PATH
installChaincodeJava "peer1.clearinghouse.example.com" "splunk_cc" "ClearinghouseMSP" $VERSION $CHAINCODE_PATH
installChaincodeJava "peer0.manufacturer.example.com" "splunk_cc" "ManufacturerMSP" $VERSION $CHAINCODE_PATH
installChaincodeJava "peer1.manufacturer.example.com" "splunk_cc" "ManufacturerMSP" $VERSION $CHAINCODE_PATH
# Upgrade chaincode on each channel.
upgradeChaincode "peer0.manufacturer.example.com" "oil-orders" "splunk_cc" "ManufacturerMSP" $VERSION
upgradeChaincode "peer0.manufacturer.example.com" "credit-letters" "splunk_cc" "ManufacturerMSP" $VERSION
upgradeChaincode "peer0.manufacturer.example.com" "poc-bids" "splunk_cc" "ManufacturerMSP" $VERSION
upgradeChaincode "peer0.manufacturer.example.com" "supply-info" "splunk_cc" "ManufacturerMSP" $VERSION
upgradeChaincode "peer0.manufacturer.example.com" "plastic-buys" "splunk_cc" "ManufacturerMSP" $VERSION
upgradeChaincode "peer0.manufacturer.example.com" "loan-payments" "splunk_cc" "ManufacturerMSP" $VERSION