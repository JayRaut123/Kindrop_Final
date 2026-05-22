const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');

const pickupRoutes = require('./routes/pickupRoutes');
const app = express(); // Create an Express application
const server = http.createServer(app); // Create an HTTP server
const io = socketIo(server, {
    cors: { origin: "*" }
}); // Create a Socket.IO server and allow CORS from any origin 


app.use(cors()); // Enable CORS for all routes
app.use(express.json()); // Middleware to parse JSON bodies

// ── Bypass loca.lt browser warning page for ALL requests ──────────────────
app.use((req, res, next) => {
    res.setHeader('Bypass-Tunnel-Reminder', 'true');
    next();
});

app.use(express.static(__dirname)); // Serve static files like donate.html

app.use("/pickup", pickupRoutes); // Use the pickup routes

io.on('connection', (socket) => {
    console.log("User Connected");

    socket.on("locationUpdate", (data) => {
        io.emit("receiveLocation", data);// Broadcast the location update to all connected clients
    });

    socket.on("updateLocation", (data) => {
        io.emit("receiveLocation", data);// Forward updateLocation payload as well
    });

    socket.on("driverAssigned", (data) => {
        io.emit("pickupSelected", data); // Broadcast that a driver started a route!
    });

    socket.on("orderPickedUp", (data) => {
        io.emit("orderPickedUp", data); // Broadcast that phase 1 finished and phase 2 has begun!
    });

    socket.on("deliveryCompleted", (data) => {
        io.emit("deliveryCompleted", data); // Broadcast that delivery successfully finished
    });
});

require('dotenv').config();
const { spawn } = require('child_process');
const fs   = require('fs');
const path = require('path');
const https = require('https');

// ── Firebase project config (same as Flutter firebase_options.dart) ──────────
const FIREBASE_PROJECT = 'kindrop-d6823';
const FIREBASE_API_KEY  = 'AIzaSyBsWXOi4APMNSCSTuKeZ3pdIbyXbxgUEs4';

// Write the live tunnel URL to Firestore document config/tunnel
async function pushUrlToFirestore(url) {
    const firestoreUrl =
        `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT}/databases/(default)/documents/config/tunnel?key=${FIREBASE_API_KEY}`;
    const body = JSON.stringify({
        fields: { url: { stringValue: url } }
    });
    return new Promise((resolve) => {
        const req = https.request(firestoreUrl, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
        }, (res) => {
            res.on('data', () => {});
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    console.log('✅ URL saved to Firestore — Flutter will auto-detect it!');
                } else {
                    console.log(`⚠️  Firestore write returned ${res.statusCode}. Flutter may need manual update.`);
                }
                resolve();
            });
        });
        req.on('error', (e) => { console.log('⚠️  Firestore write failed:', e.message); resolve(); });
        req.write(body);
        req.end();
    });
}

// Spawn cloudflared binary directly — most reliable, no API dependency issues
function startTunnel() {
    console.log('🔌 Starting Cloudflare Tunnel...');
    const cfBin = path.join(__dirname, 'node_modules', 'cloudflared', 'bin', 'cloudflared.exe');
    const cf = spawn(cfBin, ['tunnel', '--url', 'http://localhost:5000'], {
        stdio: ['ignore', 'pipe', 'pipe']
    });

    let urlFound = false;
    cf.stderr.on('data', (data) => {
        const text = data.toString();
        const match = text.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
        if (match && !urlFound) {
            urlFound = true;
            const url = match[0];
            console.log(`\n🌍 Tunnel Active: ${url}`);
            console.log(`   donate.html   → ${url}/donate.html`);
            console.log(`   delivery.html → ${url}/delivery.html\n`);
            fs.writeFileSync(path.join(__dirname, 'tunnel_url.txt'), url);
            pushUrlToFirestore(url); // 🔥 Push to Firestore → Flutter auto-reads!
        }
    });

    cf.on('exit', (code) => {
        console.log(`⚠️  Tunnel exited (code ${code}). Restarting in 3s...`);
        setTimeout(startTunnel, 3000);
    });

    cf.on('error', (err) => { console.log('⚠️  Cloudflared error:', err.message); });
}

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.log('⚠️  Port 5000 is busy. Killing old process and retrying...');
        require('child_process').exec('netstat -ano | findstr :5000', (e, out) => {
            const pid = (out.match(/\s+(\d+)\s*$/) || [])[1];
            if (pid) require('child_process').exec(`taskkill /PID ${pid} /F`, () => server.listen(5000));
        });
    } else { throw err; }
});

server.listen(5000, () => {
    console.log('Server running on port 5000');
    startTunnel();
});