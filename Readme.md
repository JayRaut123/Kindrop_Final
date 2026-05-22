# Kindrop - Technical Architecture & Viva Preparation Guide

This document is a comprehensive technical breakdown of the Kindrop project. It explains the core architecture, data flows, and technical decisions made during the development of the application. It is designed to help you confidently answer questions during your project viva.

---

## 1. High-Level System Architecture
Kindrop operates on a decoupled Client-Server architecture to separate the user interface from business logic and database management.

* **Frontend (Mobile App)**: Built using **Flutter** (Dart), providing a cross-platform mobile application for donors to submit requests.
* **Backend API & Real-Time Server**: Built using **Node.js** with the **Express.js** framework. It handles HTTP requests, REST APIs, and WebSocket connections.
* **Database**: **PostgreSQL** is the primary relational database used to store persistent data such as user records, donation details, and pickup statuses.
* **Real-time Sync & Authentication**: **Firebase / Firestore** is utilized for authentication and acts as a secondary sync layer for cross-device state management.
* **Web Views**: **HTML/CSS/Vanilla JS** are used strictly for the complex live tracking interfaces (`index.html` and `delivery.html`), rendered inside the Flutter app using a WebView.

---

## 2. Real-Time Tracking & Mapping Engine (The Core Feature)

The most complex part of Kindrop is the live donation tracker. Unlike standard Flutter Google Maps integrations, Kindrop embeds custom HTML files (`index.html` for Donors, `delivery.html` for Delivery Partners) into the Flutter app via `WebViewWidget`.

### Why WebViews for Tracking?
**Viva Question:** *"Why didn't you just use Flutter's native Google Maps package?"*
**Answer:** "Native Flutter map markers are static and require heavy state management to animate smoothly. By rendering a local HTML file inside a WebView, we utilized the native **Google Maps JavaScript API**. This allowed us to execute highly complex, 60fps animations (like the truck moving continuously, GSAP confetti animations, and sliding CSS bottom sheets) without choking the Flutter UI thread. It also made the tracker logic instantly deployable to Web browsers for cross-platform dashboards."

### How Socket.IO Syncs the Tracking
Real-time tracking is achieved entirely via **Socket.IO** (WebSockets), which establishes a persistent, bi-directional connection between the Donor, the Node.js Server, and the Delivery Partner.

**The Tracking Flow:**
1. **Initial Connect**: Both `index.html` and `delivery.html` connect to the Node server using `const socket = io();`.
2. **Phase 1 (Driver to Donor)**:
   * When a driver accepts a pickup, `delivery.html` emits a `driverAssigned` event.
   * The server broadcasts this to the Donor (`index.html`). The Donor's waiting radar disappears, and the map draws a Polyline (orange line) from the Driver's location to the Donor's location.
   * The Driver's app runs a `setInterval` loop (`simulateDriverMovement()`), which breaks down the distance into 400 frames, emitting an `updateLocation` event every few frames.
   * The Donor's map receives these coordinates and seamlessly updates the truck marker's position (`truckMarker.setPosition()`).
3. **Arrival & Phase 2 (Donor to NGO)**:
   * Once the driver arrives, the driver clicks "Confirm Order Pickup".
   * This fires an `orderPickedUp` socket event. The Node.js server relays this to the Donor.
   * The Donor's map instantly transitions: it clears the old orange line, draws a new green line to the Orphanage/NGO, and sets the state to `activePhase = 2`.
   * The driver's map calculates a new simulation trajectory and continues emitting `updateLocation`, now tracking towards the NGO.
4. **Delivery Success**:
   * Once Phase 2 completes, `deliveryCompleted` is emitted. Both dashboards wipe the active target, and trigger a JS confetti animation layer.

### Mobile Responsiveness (CSS Media Queries)
To ensure the complex HTML map looks perfect inside the Flutter WebView, we implemented dynamic CSS Media Queries (`@media (max-width: 768px)`) and Dynamic Viewport Heights (`100dvh`). This prevents mobile swipe gesture bars (like Android navigation) from clipping the map UI, allowing the tracking panels to act as elegant, collapsible bottom sheets.

---

## 3. AI Quality Verification (Gemini Integration)

To prevent users from donating torn or heavily damaged clothing, Kindrop integrates Google's **Gemini AI** (`gemini-2.5-flash` model) directly into the donation flow.

**How it works (`clothes_donation_screen.dart`):**
1. The user captures an image using the `image_picker` package.
2. The image is converted to a binary byte array and bundled with a highly specific AI prompt.
3. The prompt explicitly instructs the AI to act as a strict Quality Inspector. It demands a `True`/`False` JSON response based on whether the clothing is visibly torn, heavily stained, or inappropriate.
4. The Flutter app uses the `google_generative_ai` SDK to send this payload to the Google AI Studio API.
5. If the AI detects damage, it throws a localized error preventing the submission.

**Viva Question:** *"How do you handle API limits or Gemini downtime?"*
**Answer:** "The application uses robust `try-catch` exception handling around the API call. If a `QuotaExceeded` error occurs, the app elegantly falls back, providing the user with a clean error message asking them to try again later, rather than crashing the app."

---

## 4. Backend Synchronization & REST APIs

The backend (`pickupController.js`) handles the persistent state of all donations.

1. **Creating a Donation**: When the Flutter app submits the donation form, it performs a `POST` request to `/pickup`. The Node server writes this data into the PostgreSQL `pickups` table using a parameterized query (preventing SQL injection).
2. **Fetching Active Requests**: The Delivery Dashboard constantly polls the backend (`GET /pickups`) to load pending requests onto the map sidebar.
3. **Completing a Donation**: When the driver finishes the route, `delivery.html` makes a `DELETE /pickup/complete/:id` REST API call. The Node backend securely deletes the row from PostgreSQL.

### Firestore Dual-Sync Mechanism
Kindrop is heavily integrated with Firebase Authentication. To keep user profiles perfectly synced, the backend Controller actively mirrors the PostgreSQL data into **Google Cloud Firestore**. 
If a donation is deleted upon delivery, the backend actively reaches into Firestore and updates the document status to `Completed`, ensuring the donor's mobile profile history reflects the real-time truth.

---

## 5. Potential Viva Questions & Key Terminology

**1. What is the difference between REST APIs and WebSockets (Socket.io)?**
* **REST** is one-way communication (Client asks Server for data). Used for creating donations.
* **WebSockets** is persistent, two-way communication. Used for the map tracker so the server can push GPS coordinates to the donor without the donor constantly refreshing.

**2. How did you handle UI blocking during the Gemini AI check?**
We used asynchronous programming (`async/await`) in Dart. While waiting for the AI's HTTP response, the UI thread remains unblocked and displays a `CircularProgressIndicator` inside a transparent loading overlay.

**3. Why did you use PostgreSQL instead of just using Firebase for everything?**
PostgreSQL is a relational database. It excels at handling complex structured data, relationships, and geospatial queries if needed in the future. Firebase Firestore is a NoSQL document database, which is fast but lacks the robust relational query power of SQL. By using both, we get the best of both worlds (SQL for core backend integrity, Firebase for fast mobile syncing).

---

## 6. Important Functions & Their Logic

Be prepared to explain these core functions, as they represent the engine of the Kindrop application.

### A. Flutter Code (Mobile App)

1. **`_verifyImageQuality()`** (in `clothes_donation_screen.dart`)
   * **Logic:** Converts the user's selected image into binary bytes and passes it to Google's Generative AI (`gemini-2.5-flash`) alongside a strict prompt.
   * **How it works:** It acts as a gatekeeper. It parses the AI's JSON response (`{"isValid": true/false, "reason": "..."}`). If the AI flags the item as heavily torn or inappropriate, it blocks the donation and shows a SnackBar with the exact reason.

2. **`_submitDonation()`** (in donation screens)
   * **Logic:** Gathers form data (quantities, address, coordinates), validates inputs, and triggers the AI check if applicable.
   * **How it works:** Compiles the data into a JSON payload and executes an asynchronous HTTP `POST` request to the Node.js backend. Upon receiving a `201 Created` success code, it navigates the user directly to the live tracking Webview.

3. **`_getCurrentLocation()`**
   * **Logic:** Utilizes the `geolocator` package to ping the device's GPS hardware.
   * **How it works:** Extracts accurate latitude and longitude coordinates. This is crucial because the Delivery Partner's map relies entirely on these coordinates to calculate the driving route to the donor's doorstep.

4. **`WebViewWidget` Initialization**
   * **Logic:** Bridges native Flutter with web technologies by loading a `WebViewController`.
   * **How it works:** Instead of rebuilding complex animations natively, it loads `index.html` and passes the user's secure token/ID via URL parameters. This sandboxes the heavy Google Maps JS API and Socket.io engine away from the main Flutter thread.

### B. Node.js Backend (`server.js` & `pickupController.js`)

1. **`createPickup()`**
   * **Logic:** The primary API endpoint (`POST /pickup`). Uses parameterized SQL queries to insert data into PostgreSQL.
   * **How it works:** After saving to SQL, it executes a secondary sync using `admin.firestore().collection().doc().set()` to mirror the request into Firebase. This guarantees the user's mobile app history screen (which listens to Firebase) updates instantly.

2. **`io.on('connection')` & WebSockets**
   * **Logic:** Initializes the Socket.io server to listen for active tracking events (`driverAssigned`, `updateLocation`, `orderPickedUp`, `deliveryCompleted`).
   * **How it works:** Acts as the Grand Traffic Controller. When `delivery.html` emits a truck's new GPS coordinate, this function immediately uses `io.emit()` to broadcast that coordinate to the specific Donor, creating the illusion of real-time movement.

3. **`completePickup()`**
   * **Logic:** Handles the `DELETE /pickup/complete/:id` request when a driver reaches the NGO.
   * **How it works:** Removes the active tracking row from PostgreSQL to clean the queue, and updates the Firestore document status from `Pending` to `Completed`.

### C. Web Tracking Maps (`index.html` & `delivery.html`)

1. **`simulateDriverMovement()`** (in `delivery.html`)
   * **Logic:** Calculates the mathematical vector between the driver's current coordinate and the target coordinate. Uses a JavaScript `setInterval` loop to break the distance into 400 micro-steps.
   * **How it works:** Every 40 milliseconds, it physically moves the truck marker on the driver's screen and emits high-frequency `updateLocation` socket packets. This handles Phase 1 (To Donor) and Phase 2 (To NGO) animations.

2. **`fetchETA()`** (in `delivery.html`)
   * **Logic:** Constructs a request to the Google Maps Distance Matrix API.
   * **How it works:** Rather than guessing distance using straight lines (Haversine formula), it asks Google for real-world driving time avoiding traffic and buildings, updating the `Est. Distance left` UI dynamically.

3. **`socket.on("receiveLocation")`** (in `index.html`)
   * **Logic:** The listener function on the Donor's dashboard that intercepts the high-frequency telemetry pings from the server.
   * **How it works:** It uses `truckMarker.setPosition()` to smoothly glide the truck icon across the map. It also contains "Auto-Recovery" logic—if the mobile network drops a packet, it reads the `data.phase` flag to instantly snap the UI back into sync (e.g., automatically switching to Phase 2 if the "Order Picked Up" signal was lost).

4. **`socket.on("deliveryCompleted")`** (in `index.html`)
   * **Logic:** Triggered at the exact end of the route.
   * **How it works:** Wipes the active map trackers, clears the routing polyline, and mathematically generates 60 floating dots using keyframe CSS animations to launch the immersive Confetti success overlay.

---

## 7. Mathematical Formulae & Algorithms Used

During the viva, you may be asked how distances, times, and movements are calculated mathematically. Here is the breakdown of the exact mathematical concepts and algorithms running inside the codebase:

### 1. Estimated Time of Arrival (ETA) & Distance Matrix
**Where it's used:** `fetchETA()` in `delivery.html`
**The Algorithm:** Instead of guessing the time using a simple Speed = Distance / Time formula (which ignores traffic, one-way streets, and road curves), our application relies on **Dijkstra's Algorithm / A* Search Algorithm** operating remotely via the **Google Maps Distance Matrix API**.
* **How it works:** We pass the `origin` (driver's live coordinates) and `destination` (NGO or Donor) to Google's servers. Google calculates the most efficient route across its massive graph network of roads, factors in real-time traffic data, and returns highly accurate `duration` (e.g., "14 mins") and `distance` (e.g., "5.2 km") strings. This guarantees our ETA is production-ready and realistic.

### 2. The Haversine Formula (Great-Circle Distance)
**Where it's used:** `google.maps.geometry.spherical.computeDistanceBetween(driverPos, targetPos)` in `index.html`
**The Formula:** 
```text
a = sin²(Δφ/2) + cos φ1 ⋅ cos φ2 ⋅ sin²(Δλ/2)
c = 2 ⋅ atan2( √a, √(1−a) )
d = R ⋅ c
```
*(Where φ is latitude, λ is longitude, and R is Earth's radius ~6,371 km)*
* **How it works:** Because the Earth is a sphere, you cannot calculate the distance between two GPS coordinates using simple flat 2D geometry (Pythagorean theorem). The **Haversine formula** calculates the shortest distance over the Earth's curved surface. 
* **Application in code:** We use this formula as a fallback to calculate the strict "air-line" distance in kilometers (`distKm`) to show the user exactly how far the truck is in real-time, even between API calls.

### 3. Linear Interpolation (LERP) for Animation
**Where it's used:** `simulateDriverMovement()` and `simulatePhase2Movement()` in `delivery.html`
**The Formula:** 
```javascript
CurrentPoint = StartPoint + ((TargetPoint - StartPoint) * (CurrentStep / TotalSteps))
```
* **How it works:** To make the truck move smoothly across the screen during the simulation, we use mathematical **Linear Interpolation**. 
* **Application in code:** We set a `TOTAL_STEPS` variable (e.g., 400 steps). A `setInterval` loop runs every 40ms. On each tick, we calculate the exact fractional GPS coordinate that lies between the driver's start location and the destination. This guarantees the truck glides smoothly at a constant velocity without stuttering, simulating a real GPS hardware feed.

### 4. Global Positioning System (GPS) Trilateration
**Where it's used:** `_getCurrentLocation()` via the Flutter `geolocator` package.
* **How it works:** When the donor taps "Use Current Location", the phone's GPS receiver calculates its distance from at least four Earth-orbiting satellites based on the time it takes for radio signals to travel. This intersection of spheres (**Trilateration**) provides the exact latitude and longitude coordinates injected into our application.

---

## 8. Comprehensive System Flowchart

*(You can easily copy and paste this text-based flowchart directly into Microsoft Word, Google Docs, or PDF without needing any third-party diagram renderers. It is designed to be highly readable and aesthetic.)*

```text
=========================================================
                 PHASE 1: DONOR REQUEST
=========================================================
  [ 📱 FLUTTER MOBILE APP ]
      │
      ├──➔ 1. Login via Firebase Authentication
      │
      ├──➔ 2. Select Donation Type (Clothes / Stationery)
      │
      ├──➔ 3. Gemini AI Verification (For Clothes)
      │       ↳ IF Valid: Proceeds to next step
      │       ↳ IF Invalid: Blocks donation, shows error
      │
      ├──➔ 4. Extract Live GPS Coordinates (Geolocator)
      │
      └──➔ 5. Submit Donation (HTTP POST /pickup)
                  │
                  ▼
=========================================================
               PHASE 2: BACKEND PROCESSING
=========================================================
  [ ⚙️ NODE.JS BACKEND & DATABASE ]
      │
      ├──➔ 1. createPickup() Controller Validates Payload
      │
      ├──➔ 2. SQL INSERT ➔ Saves to PostgreSQL (pickups table)
      │
      └──➔ 3. Firestore Sync ➔ Mirrors record to Firebase
                  │
                  ▼
=========================================================
            PHASE 3: DELIVERY & LIVE TRACKING
=========================================================
  [ 🚚 HTML/JS DELIVERY DASHBOARD & SOCKET.IO ]
      │
      ├──➔ 1. Driver Accepts Request
      │       ↳ Emits "driverAssigned" socket event
      │
      ├──➔ 2. Live Tracking Engine Starts (simulateDriverMovement)
      │       ↳ LERP algorithm calculates micro-steps
      │       ↳ Emits "updateLocation" every 40ms
      │       ↳ Google Maps API fetches accurate ETA
      │
      ├──➔ 3. Donor Dashboard Updates (Phase 1)
      │       ↳ Reads socket pings ➔ Moves Truck icon smoothly
      │
      ├──➔ 4. Driver Reaches Donor ➔ Clicks "Confirm Pickup"
      │       ↳ Emits "orderPickedUp" socket event
      │
      ├──➔ 5. Route Switches to NGO (Phase 2)
      │       ↳ Donor Map: Draws Green Line to Orphanage
      │       ↳ Driver Map: Animates towards NGO
      │
      └──➔ 6. Driver Reaches NGO ➔ Delivery Completed
                  │
                  ▼
=========================================================
               PHASE 4: SYSTEM CLEANUP
=========================================================
  [ 🧹 DATABASE & UI FINALIZATION ]
      │
      ├──➔ 1. Emits "deliveryCompleted" 
      │       ↳ Donor App: Triggers Confetti Success UI
      │
      ├──➔ 2. HTTP DELETE /pickup/complete/:id
      │
      ├──➔ 3. SQL DELETE ➔ Removes active record from PostgreSQL
      │
      └──➔ 4. Firestore Sync ➔ Updates status to "Completed"
=========================================================
```

---
**Prepared by:** Antigravity (Google DeepMind Agentic Coding Framework)
