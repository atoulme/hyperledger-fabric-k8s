package com.splunk.chaincode.pocbids;

import io.jaegertracing.internal.samplers.ConstSampler;
import io.jaegertracing.zipkin.ZipkinV2Reporter;
import io.opentracing.Span;
import io.opentracing.Tracer;
import io.opentracing.util.GlobalTracer;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contact;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.License;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.shim.ledger.CompositeKey;
import org.hyperledger.fabric.shim.ledger.KeyValue;
import zipkin2.reporter.AsyncReporter;
import zipkin2.reporter.okhttp3.OkHttpSender;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import static java.nio.charset.StandardCharsets.UTF_8;

@Contract(name = "BidContract",
        info = @Info(title = "Bid contract",
                description = "Contract capturing bids",
                version = "0.0.1",
                license =
                @License(name = "SPDX-License-Identifier: Apache-2.0",
                        url = ""),
                contact = @Contact(email = "clearinghouse@example.com",
                        name = "Clearing House",
                        url = "http://example.com")))
@Default
public class BidContract implements ContractInterface {

    private static final Tracer tracer = createTracer();

    // adapted from https://github.com/signalfx/tracing-examples/blob/master/jaeger-java/src/main/java/com/signalfx/tracing/examples/jaeger/App.java
    private static io.opentracing.Tracer createTracer() {
        Map<String, String> env = System.getenv();

        String ingestUrl = System.getProperty("ingestUrl", env.getOrDefault("ingestUrl", "http://sfxagent:9080/v1/trace"));

        // Build the sender that does the HTTP request containing spans to our ingest server.
        OkHttpSender.Builder senderBuilder = OkHttpSender.newBuilder()
                .compressionEnabled(true)
                .endpoint(ingestUrl + "/v1/trace");

        OkHttpSender sender = senderBuilder.build();

        // Build the Jaeger Tracer instance, which implements the opentracing Tracer interface.
        io.opentracing.Tracer tracer = new io.jaegertracing.Configuration("bidcontract")
                // We need to get a builder so that we can directly inject the
                // reporter instance.
                .getTracerBuilder()
                // This configures the tracer to send all spans, but you will probably want to use
                // something less verbose.
                .withSampler(new ConstSampler(true))
                // Configure the tracer to send spans in the Zipkin V2 JSON format instead of the
                // default Jaeger UDP protocol, which we do not support.
                .withReporter(new ZipkinV2Reporter(AsyncReporter.create(sender)))
                .build();

        // It is considered best practice to at least register the GlobalTracer instance, even if you
        // don't generally use it.
        GlobalTracer.register(tracer);

        return tracer;
    }

    public BidContract() {

    }

    @Transaction()
    public boolean myAuctionExists(Context ctx, String myAssetId) {
        byte[] buffer = ctx.getStub().getState(myAssetId);
        return (buffer != null && buffer.length > 0);
    }

    @Transaction()
    public boolean myBidExists(Context ctx, String auctionId, String bidId) {
        CompositeKey key = ctx.getStub().createCompositeKey("bid", auctionId, bidId);
        byte[] buffer = ctx.getStub().getState(key.toString());
        return (buffer != null && buffer.length > 0);
    }

    @Transaction()
    public void createAuction(Context ctx, String auctionId, String name) {
        boolean exists = myAuctionExists(ctx, auctionId);
        if (exists) {
            throw new RuntimeException("The bid " + auctionId + " already exists");
        }

        Auction asset = new Auction();
        asset.setName(name);
        asset.setActive(true);
        CompositeKey key = ctx.getStub().createCompositeKey("auction", "active", auctionId);
        ctx.getStub().putState(key.toString(), asset.toJSONString().getBytes(UTF_8));
    }

    @Transaction()
    public void createBid(Context ctx, String bidId, Double value, String auctionId, String traceId) {
        Span span = tracer.buildSpan("createBid").withTag("traceId", traceId).withTag("auctionId", auctionId).start();
        span.setTag("span.kind", "server");
        try {
            boolean exists = myBidExists(ctx, auctionId, bidId);
            if (exists) {
                throw new RuntimeException("The bid " + bidId + " already exists");
            }
            boolean auctionExists = myAuctionExists(ctx, auctionId);
            if (!auctionExists) {
                throw new RuntimeException("The auction " + auctionId + " doesn't exist");
            }
            Bid asset = new Bid();
            asset.setValue(value);
            asset.setWinner(false);
            asset.setTraceId(traceId);
            asset.setAuctionId(auctionId);
            CompositeKey key = ctx.getStub().createCompositeKey("bid", auctionId, bidId);
            ctx.getStub().putState(key.toString(), asset.toJSONString().getBytes(UTF_8));
        } catch (Throwable t) {
            span.setTag("error", "true");
        } finally {
            span.finish();
        }
    }

    @Transaction()
    public Bid readBid(Context ctx, String auctionId, String bidId) {
        boolean exists = myBidExists(ctx, auctionId, bidId);
        if (!exists) {
            throw new RuntimeException("The bid " + bidId + " does not exist");
        }

        CompositeKey key = ctx.getStub().createCompositeKey("bid", auctionId, bidId);
        Bid newBid = Bid.fromJSONString(new String(ctx.getStub().getState(key.toString()), UTF_8));
        return newBid;
    }

    @Transaction()
    public Auction readAuction(Context ctx, String myAssetId) {
        boolean exists = myAuctionExists(ctx, myAssetId);
        if (!exists) {
            throw new RuntimeException("The auction " + myAssetId + " does not exist");
        }

        Auction auction = Auction.fromJSONString(new String(ctx.getStub().getState(myAssetId), UTF_8));
        return auction;
    }

    @Transaction()
    public void selectWinnerBid(Context ctx, String auctionId, String winnerBidId) {
        Bid bid = readBid(ctx, auctionId, winnerBidId);
        Auction auction = readAuction(ctx, bid.getAuctionId());
        bid.setWinner(true);
        auction.setActive(false);
        ctx.getStub().putState(winnerBidId, bid.toJSONString().getBytes(UTF_8));
        CompositeKey activeKey = ctx.getStub().createCompositeKey("auction", "active", bid.getAuctionId());
        ctx.getStub().delState(activeKey.toString());
        CompositeKey key = ctx.getStub().createCompositeKey("auction", "inactive", bid.getAuctionId());
        ctx.getStub().putState(key.toString(), auction.toJSONString().getBytes(UTF_8));
    }

    @Transaction
    public List<Bid> readAuctionBids(Context ctx, String auctionId) {
        CompositeKey key = ctx.getStub().createCompositeKey("bid", auctionId);
        List<Bid> bids = new ArrayList<>();
        Iterator<KeyValue> values = ctx.getStub().getStateByPartialCompositeKey(key).iterator();
        while (values.hasNext()) {
            KeyValue kv = values.next();
            bids.add(Bid.fromJSONString(kv.getStringValue()));
        }
        return bids;
    }

    @Transaction()
    public List<Auction> readAllActiveAuctions(Context ctx) {
        CompositeKey key = ctx.getStub().createCompositeKey("auction", "active");
        List<Auction> auctions = new ArrayList<>();
        Iterator<KeyValue> values = ctx.getStub().getStateByPartialCompositeKey(key).iterator();
        while (values.hasNext()) {
            KeyValue kv = values.next();
            auctions.add(Auction.fromJSONString(kv.getStringValue()));
        }
        return auctions;
    }

    @Transaction()
    public List<Auction> readAllInactiveAuctions(Context ctx) {
        CompositeKey key = ctx.getStub().createCompositeKey("auction", "inactive");
        List<Auction> auctions = new ArrayList<>();
        Iterator<KeyValue> values = ctx.getStub().getStateByPartialCompositeKey(key).iterator();
        while (values.hasNext()) {
            KeyValue kv = values.next();
            auctions.add(Auction.fromJSONString(kv.getStringValue()));
        }
        return auctions;
    }

}