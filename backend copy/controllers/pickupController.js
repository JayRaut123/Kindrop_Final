const pool = require("../db");
const axios = require("axios");

exports.createPickup = async (req, res) => {

  const {
    donor_name,
    donor_address,
    donor_lat,
    donor_lng,
    orphanage_name,
    ngo_lat,
    ngo_lng,
    firebase_id
  } = req.body;

  const result = await pool.query(
    `INSERT INTO pickups
    (donor_name, donor_address, donor_lat, donor_lng, orphanage_name, ngo_lat, ngo_lng, status, firebase_id)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
    RETURNING *`,
    [donor_name, donor_address, donor_lat, donor_lng, orphanage_name, ngo_lat, ngo_lng, "pending", firebase_id]
  );

  res.json(result.rows[0]);
};

exports.getPickups = async (req, res) => {

 const result = await pool.query(
 "SELECT * FROM pickups"
 );

 res.json(result.rows);

};

exports.updateDriverLocation = async (req, res) => {

 const { id, lat, lng } = req.body;

 await pool.query(
 `UPDATE pickups
 SET driver_lat=$1, driver_lng=$2
 WHERE id=$3`,
 [lat, lng, id]
 );

 res.json({message:"location updated"});

};

exports.getETA = async (req, res) => {
  try {
    const { origin, destination } = req.query;
    if (!origin || !destination) {
      return res.status(400).json({ error: "Missing origin or destination" });
    }

    // Attempted exact route API call, defaulting to Math fallback on error/billing
    try {
        const apiKey = process.env.GOOGLE_API_KEY;
        const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin}&destinations=${destination}&key=${apiKey}`;
        const response = await axios.get(url);
        
        // If Google API works and isn't blocked by billing limits!
        if(response.data.status === "OK" && !response.data.error_message) {
             return res.json(response.data);
        }
    } catch(apiErr) {
        console.log("Google API Failed, falling back to Math Calculation");
    }

    // ======= OFFLINE MATHEMATICAL FALLBACK =======
    // Because Google Maps requires a verified credit card for Distance Matrix.
    const [lat1, lon1] = origin.split(',').map(Number);
    const [lat2, lon2] = destination.split(',').map(Number);

    // Haversine formula for exact distance between two coordinates
    const R = 6371; // Earth's radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const straightDistance = R * c; // in km

    // Add a 40% penalty because roads aren't straight lines
    const drivingDistanceKm = straightDistance * 1.4;
    
    // Average city driving speed (Mumbai ~ 22 km/h)
    const exactHours = drivingDistanceKm / 22;
    const exactMins = Math.round(exactHours * 60);

    // Format text beautifully
    let timeText = exactMins < 1 ? "1 min" : `${exactMins} mins`;
    if(exactMins >= 60) {
        const h = Math.floor(exactMins / 60);
        const m = exactMins % 60;
        timeText = `${h} hr ${m} mins`;
    }

    // Create a Fake "Google API" Response so the frontend parsing doesn't break!
    res.json({
        status: "OK",
        rows: [{
            elements: [{
                status: "OK",
                distance: { text: drivingDistanceKm.toFixed(1) + " km", value: drivingDistanceKm * 1000 },
                duration: { text: timeText, value: exactMins * 60 }
            }]
        }]
    });

  } catch (error) {
    console.error("ETA Calculation Error:", error);
    res.status(500).json({ error: "Failed to calculate ETA mathematically" });
  }
};

exports.completePickup = async (req, res) => {
  const { id } = req.params;
  try {
      const getResult = await pool.query('SELECT firebase_id FROM pickups WHERE id = $1', [id]);
      const fid = getResult.rows[0]?.firebase_id;
      
      await pool.query('DELETE FROM pickups WHERE id = $1', [id]);

      // If tied to Firebase app, update the status to Completed!
      if (fid) {
          const FIREBASE_PROJECT = 'kindrop-d6823';
          const FIREBASE_API_KEY  = 'AIzaSyBsWXOi4APMNSCSTuKeZ3pdIbyXbxgUEs4';
          const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT}/databases/(default)/documents/donations/${fid}?updateMask.fieldPaths=status&key=${FIREBASE_API_KEY}`;
          const body = JSON.stringify({ fields: { status: { stringValue: 'Completed' } } });
          
          await axios.patch(firestoreUrl, body, {
              headers: { 'Content-Type': 'application/json' }
          }).catch(e => console.error("Could not sync with Firestore", e.message));
      }

      res.json({ message: "Pickup successfully deleted/completed." });
  } catch (error) {
      console.error("Deletion Error:", error);
      res.status(500).json({ error: "Failed to delete pickup record." });
  }
};