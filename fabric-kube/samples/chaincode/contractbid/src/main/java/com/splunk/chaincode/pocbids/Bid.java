package com.splunk.chaincode.pocbids;

import com.google.gson.JsonObject;
import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;
import org.json.JSONObject;

@DataType()
public class Bid {

    @Property()
    private Double value;
    @Property()
    private String auctionId;
    @Property()
    private boolean winner;
    @Property
    private String traceId;

    public Bid(){
    }

    public Double getValue() {
        return value;
    }

    public void setValue(Double value) {
        this.value = value;
    }

    public boolean isWinner() {
        return winner;
    }

    public void setAuctionId(String auctionId) {
        this.auctionId = auctionId;
    }

    public String getAuctionId() {
        return auctionId;
    }

    public void setWinner(boolean b) {
        winner = b;
    }

    public String getTraceId() {
        return traceId;
    }

    public void setTraceId(String traceId) {
        this.traceId = traceId;
    }

    public String toJSONString() {
        return new JSONObject(this).toString();
    }

    public static Bid fromJSONString(String json) {
        JSONObject pojo = new JSONObject(json);
        Double value = pojo.getDouble("value");
        String auctionId = pojo.getString("auctionId");
        boolean winner = pojo.getBoolean("winner");
        String traceId = pojo.getString("traceId");
        Bid asset = new Bid();
        asset.setValue(value);
        asset.setAuctionId(auctionId);
        asset.setWinner(winner);
        asset.setTraceId(traceId);
        return asset;
    }


}