package com.splunk.chaincode.pocbids;

import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;
import org.json.JSONObject;

@DataType()
public class Auction {

    @Property()
    private String name;
    @Property()
    private boolean active;

    public Auction(){
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public String toJSONString() {
        return new JSONObject(this).toString();
    }

    public static Auction fromJSONString(String json) {
        JSONObject pojo = new JSONObject(json);
        String name = pojo.getString("name");
        boolean active = pojo.getBoolean("active");
        Auction asset = new Auction();
        asset.setName(name);
        asset.setActive(active);
        return asset;
    }
}
