#!/usr/bin/env node
/**
 * Simple NATS Pub/Sub Example
 * 
 * Run with: node simple-pubsub.js
 * 
 * This demonstrates basic publish/subscribe patterns with NATS
 */

import { connect, StringCodec } from 'nats';

const sc = StringCodec();

async function main() {
    try {
        // Connect to NATS server
        const nc = await connect({ 
            servers: 'nats://localhost:4222',
            name: 'simple-pubsub-example'
        });
        
        console.log('✅ Connected to NATS server');
        
        // Set up subscriber
        const sub = nc.subscribe('demo.greeting');
        console.log('📡 Subscribed to "demo.greeting"');
        
        // Handle incoming messages
        (async () => {
            for await (const m of sub) {
                console.log(`📨 Received: ${sc.decode(m.data)}`);
            }
        })();
        
        // Publish some messages
        console.log('📤 Publishing messages...');
        
        for (let i = 1; i <= 5; i++) {
            const message = `Hello NATS! Message #${i}`;
            nc.publish('demo.greeting', sc.encode(message));
            console.log(`📤 Published: ${message}`);
            
            // Wait a bit between messages
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
        // Clean shutdown after a moment
        setTimeout(async () => {
            console.log('🛑 Shutting down...');
            await nc.drain();
            process.exit(0);
        }, 2000);
        
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

main();
