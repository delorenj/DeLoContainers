#!/usr/bin/env node
/**
 * NATS JetStream Example
 * 
 * Run with: node jetstream-example.js
 * 
 * This demonstrates persistent messaging with JetStream
 */

import { connect, StringCodec, AckPolicy } from 'nats';

const sc = StringCodec();

async function main() {
    try {
        // Connect to NATS server
        const nc = await connect({ 
            servers: 'nats://localhost:4222',
            name: 'jetstream-example'
        });
        
        console.log('✅ Connected to NATS server');
        
        // Get JetStream context
        const js = nc.jetstream();
        
        // Create or update a stream
        const streamName = 'DEMO_STREAM';
        try {
            await js.streams.add({
                name: streamName,
                subjects: ['demo.orders.*'],
                storage: 'file',
                max_age: 60 * 60 * 1000000000, // 1 hour in nanoseconds
                max_msgs: 1000,
                discard: 'old'
            });
            console.log(`📦 Created stream: ${streamName}`);
        } catch (error) {
            if (error.message.includes('already exists')) {
                console.log(`📦 Stream ${streamName} already exists`);
            } else {
                throw error;
            }
        }
        
        // Publish some persistent messages
        console.log('📤 Publishing persistent messages...');
        
        for (let i = 1; i <= 3; i++) {
            const order = {
                id: i,
                product: `Widget ${i}`,
                quantity: Math.floor(Math.random() * 10) + 1,
                timestamp: new Date().toISOString()
            };
            
            const ack = await js.publish(`demo.orders.new`, sc.encode(JSON.stringify(order)));
            console.log(`📤 Published order ${i}, sequence: ${ack.seq}`);
        }
        
        // Create a consumer
        const consumerName = 'order-processor';
        try {
            await js.consumers.add(streamName, {
                durable_name: consumerName,
                ack_policy: AckPolicy.Explicit,
                filter_subject: 'demo.orders.*'
            });
            console.log(`👤 Created consumer: ${consumerName}`);
        } catch (error) {
            if (error.message.includes('already exists')) {
                console.log(`👤 Consumer ${consumerName} already exists`);
            } else {
                throw error;
            }
        }
        
        // Consume messages
        console.log('📨 Consuming messages...');
        const consumer = await js.consumers.get(streamName, consumerName);
        
        let msgCount = 0;
        const messages = await consumer.consume({ max_messages: 5 });
        
        for await (const m of messages) {
            const order = JSON.parse(sc.decode(m.data));
            console.log(`📨 Processing order:`, order);
            
            // Acknowledge the message
            m.ack();
            msgCount++;
            
            if (msgCount >= 3) {
                messages.stop();
                break;
            }
        }
        
        console.log('✅ JetStream example completed');
        
        // Clean shutdown
        await nc.drain();
        
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

main();
