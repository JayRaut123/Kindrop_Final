const express = require('express');
const router = express.Router(); // Create a router for pickup-related routes

const {
    createPickup,
    getPickups,
    updateDriverLocation,
    getETA,
    completePickup
} = require("../controllers/pickupController");

router.post("/create", createPickup); // Route to create a new pickup
router.get("/all", getPickups); // Route to get all pickups

router.post("/update-location", updateDriverLocation);

router.get("/eta", getETA);
router.delete("/complete/:id", completePickup);

module.exports = router; // Export the router to be used in server.js