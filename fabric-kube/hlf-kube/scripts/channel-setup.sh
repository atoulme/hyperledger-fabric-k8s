#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

mkdir -p channel-artifacts
export MSYS_NO_PATHCONV=1
export FABRIC_CFG_PATH=/hlf_config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/hlf_config/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp/tlscacerts/cert.pem
export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/clearinghouse.example.com/users/Admin\@clearinghouse.example.com/msp
function createChannel() {
	CHANNEL_NAME=$1

	# Generate channel configuration transaction
	echo "========== Creating channel transaction for: "$CHANNEL_NAME" =========="
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ../channel-artifacts/$CHANNEL_NAME-channel.tx -channelID $CHANNEL_NAME
	res=$?
	if [ $res -ne 0 ]; then
	    echo "Failed to generate channel configuration transaction..."
	    exit 1
	fi	


	# Channel creation
	echo "========== Creating channel: "$CHANNEL_NAME" =========="
	peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ../channel-artifacts/$CHANNEL_NAME-channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
}

function joinChannel() {
	PEER_NAME=$1
	CHANNEL_NAME=$2
	MSP_ID=$3
	IS_ANCHOR=$4

	ORG_NAME=$( echo $PEER_NAME | cut -d. -f1 --complement)

	echo "========== Joining "$PEER_NAME" to channel "$CHANNEL_NAME" =========="
	export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME/msp
	export CORE_PEER_ADDRESS=$PEER_NAME:7051
	export CORE_PEER_LOCALMSPID="$MSP_ID"
	export CORE_PEER_TLS_ROOTCERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/ca.crt
	export CORE_PEER_TLS_KEY_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.key
	export CORE_PEER_TLS_CERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.crt
	peer channel join -b ${CHANNEL_NAME}.block

	if [ ${IS_ANCHOR} -ne 0 ]; then
		echo "========== Generating anchor peer definition for: "$CHANNEL_NAME" =========="
	    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ../channel-artifacts/$CHANNEL_NAME-${CORE_PEER_LOCALMSPID}anchors.tx -channelID $CHANNEL_NAME -asOrg $MSP_ID

		res=$?
		if [ $res -ne 0 ]; then
		    echo "Failed to generate channel configuration transaction..."
		    exit 1
		fi	
		# if anchor then update this.
		peer channel update -o orderer.example.com:7050 -c ${CHANNEL_NAME} -f ../channel-artifacts/${CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
	fi
}

function installChaincodeJava() {
	PEER_NAME=$1
	CHAINCODE_NAME=$2
	MSP_ID=$3
	VERSION=$4
	ORG_NAME=$( echo $PEER_NAME | cut -d. -f1 --complement)

	mkdir -p $GOPATH/src/chaincode
    tar -xf /chaincode/contractbid/contractbid.tar -C $GOPATH/src/chaincode
  cd $GOPATH/src/chaincode/contractbid/
  ./gradlew shadowJar

	echo "========== Installing chaincode [${CHAINCODE_NAME}] on ${PEER_NAME} =========="
	export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME/msp
	export CORE_PEER_ADDRESS=$PEER_NAME:7051
	export CORE_PEER_LOCALMSPID="$MSP_ID"
	export CORE_PEER_TLS_ROOTCERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/ca.crt
	export CORE_PEER_TLS_KEY_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.key
	export CORE_PEER_TLS_CERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.crt
	peer chaincode install -l java -n $CHAINCODE_NAME -v $VERSION -p $GOPATH/src/chaincode
}

function instantiateChaincodeJava() {
	PEER_NAME=$1
	CHANNEL_NAME=$2
	CHAINCODE_NAME=$3
	MSP_ID=$4
	VERSION=$5

	ORG_NAME=$( echo $PEER_NAME | cut -d. -f1 --complement)

	echo "========== Instantiating chaincode [${CHAINCODE_NAME}] on ${PEER_NAME} in ${CHANNEL_NAME} =========="
	export CORE_PEER_MSPCONFIGPATH=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME/msp
	export CORE_PEER_ADDRESS=$PEER_NAME:7051
	export CORE_PEER_LOCALMSPID="$MSP_ID"
	export CORE_PEER_TLS_ROOTCERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/ca.crt
	export CORE_PEER_TLS_KEY_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.key
	export CORE_PEER_TLS_CERT_FILE=/hlf_config/crypto-config/peerOrganizations/$ORG_NAME/peers/$PEER_NAME/tls/server.crt
	peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED \
		--cafile $ORDERER_CA \
		-C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args": []}' \
		-v $VERSION -P "OR ('ClearinghouseMSP.member','ManufacturerMSP.member')"
}



# Create any number of channels here with new names.
createChannel "oil-orders"
createChannel "credit-letters"
createChannel "poc-bids"
createChannel "supply-info"
createChannel "plastic-buys"
createChannel "loan-payments"

# Have any number of peers to join here. Third argument is ClearinghouseMSP or ManufacturerMSP, last arg is 1 or 0 for anchor peer or not. Can only have 1 anchor peer per org per channel.
joinChannel "peer0.clearinghouse.example.com" "oil-orders" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "oil-orders" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "oil-orders" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "oil-orders" "ManufacturerMSP" 0

joinChannel "peer0.clearinghouse.example.com" "credit-letters" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "credit-letters" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "credit-letters" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "credit-letters" "ManufacturerMSP" 0

joinChannel "peer0.clearinghouse.example.com" "poc-bids" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "poc-bids" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "poc-bids" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "poc-bids" "ManufacturerMSP" 0

joinChannel "peer0.clearinghouse.example.com" "supply-info" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "supply-info" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "supply-info" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "supply-info" "ManufacturerMSP" 0

joinChannel "peer0.clearinghouse.example.com" "plastic-buys" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "plastic-buys" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "plastic-buys" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "plastic-buys" "ManufacturerMSP" 0

joinChannel "peer0.clearinghouse.example.com" "loan-payments" "ClearinghouseMSP" 1
joinChannel "peer1.clearinghouse.example.com" "loan-payments" "ClearinghouseMSP" 0
joinChannel "peer0.manufacturer.example.com" "loan-payments" "ManufacturerMSP" 1
joinChannel "peer1.manufacturer.example.com" "loan-payments" "ManufacturerMSP" 0

# Install chaincode onto peers. Do not worry about channels here.
installChaincodeJava "peer0.clearinghouse.example.com" "splunk_cc" "ClearinghouseMSP" 1.0
installChaincodeJava "peer1.clearinghouse.example.com" "splunk_cc" "ClearinghouseMSP" 1.0
installChaincodeJava "peer0.manufacturer.example.com" "splunk_cc" "ManufacturerMSP" 1.0
installChaincodeJava "peer1.manufacturer.example.com" "splunk_cc" "ManufacturerMSP" 1.0

# Instantiate chaincode on each channel.
instantiateChaincodeJava "peer0.manufacturer.example.com" "oil-orders" "splunk_cc" "ManufacturerMSP" 1.0
instantiateChaincodeJava "peer0.manufacturer.example.com" "credit-letters" "splunk_cc" "ManufacturerMSP" 1.0
instantiateChaincodeJava "peer0.manufacturer.example.com" "poc-bids" "splunk_cc" "ManufacturerMSP" 1.0
instantiateChaincodeJava "peer0.manufacturer.example.com" "supply-info" "splunk_cc" "ManufacturerMSP" 1.0
instantiateChaincodeJava "peer0.manufacturer.example.com" "plastic-buys" "splunk_cc" "ManufacturerMSP" 1.0
instantiateChaincodeJava "peer0.manufacturer.example.com" "loan-payments" "splunk_cc" "ManufacturerMSP" 1.0

# These set up channel logging to Splunk
curl -X PUT fabric-logger-peer0:8080/channels/oil-orders
curl -X PUT fabric-logger-peer0:8080/channels/credit-letters
curl -X PUT fabric-logger-peer0:8080/channels/poc-bids
curl -X PUT fabric-logger-peer0:8080/channels/supply-info
curl -X PUT fabric-logger-peer0:8080/channels/plastic-buys
curl -X PUT fabric-logger-peer0:8080/channels/loan-payments
curl -X PUT -H "Content-Type: application/json" -d '{"filter":"updateEvent"}' fabric-logger-peer0:8080/channels/oil-orders/events/splunk_cc
curl -X PUT -H "Content-Type: application/json" -d '{"filter":"updateEvent"}' fabric-logger-peer0:8080/channels/poc-bids/events/splunk_cc

