
    let map, donorMarker, truckMarker, connectionLine;
    let myDonations = [];
    let activePickupId = null; // Track if a driver actively selected us
    let activeMyDonation = null; // Stash object for phase 2 routing
    let activePhase = 0; // 0 = waiting, 1 = driver headed to donor, 2 = driver headed to NGO
    let boundsLimiter = 0; // throttle bounds recalculations
    const backendUrl = 'http://localhost:5000';

    // Connect to backend Socket.IO for real-time location updates
    const socket = io(backendUrl);

    // Initialize and add the map
    function initMap() {
      const centerPoint = { lat: 28.6139, lng: 77.2090 }; // Default Location

      map = new google.maps.Map(document.getElementById("map"), {
        zoom: 12,
        center: centerPoint,
        mapTypeControlOptions: {
          position: google.maps.ControlPosition.TOP_RIGHT,
        },
        zoomControlOptions: {
          position: google.maps.ControlPosition.RIGHT_CENTER,
        },
        streetViewControlOptions: {
          position: google.maps.ControlPosition.RIGHT_CENTER,
        },
        fullscreenControlOptions: {
          position: google.maps.ControlPosition.TOP_RIGHT,
        }
      });

      // 1. Fetch existing pickups (pretending we filter by "My Pickups")
      fetch(`${backendUrl}/pickup/all`)
        .then(response => response.json())
        .then(pickups => {
          myDonations = pickups;
          renderProducts(pickups);
        })
        .catch(error => {
          console.error('Error fetching donations:', error);
          document.getElementById("products-container").innerHTML = `<div style="color:red; font-size:13px; text-align:center; padding:10px;">Failed to load data.</div>`;
        });

      // 2. Listen for the moment the driver specifically clicks OUR donation!
      socket.on("pickupSelected", (pickupData) => {
        console.log("==> SOCKET: Received pickupSelected event for ID:", pickupData.id);
        console.log("My Active Donations list:", myDonations);

        // Check if the pickup the driver selected belongs to us
        const isMyDonation = myDonations.find(d => d.id === pickupData.id);
        if (isMyDonation) {
          console.log("SUCCESS! The driver selected exactly MY donation:", isMyDonation);
          activePickupId = pickupData.id;
          activeMyDonation = isMyDonation;

          // Fade out waiting radar
          const overlay = document.getElementById("waiting-overlay");
          overlay.style.opacity = '0';
          setTimeout(() => { overlay.style.display = 'none'; }, 500);

          // 1. Show the Driver details panel!
          document.getElementById("driver-details").style.display = "block";
          document.getElementById("arriving-panel").style.display = "block";

          // 2. Add visual feedback on the item itself
          const itemTitle = document.getElementById(`donation-title-${pickupData.id}`);
          if (itemTitle && !itemTitle.innerHTML.includes('En Route')) {
            itemTitle.innerHTML += `<div class="truck-badge"><div class="dot"></div> En Route</div>`;
          }

          // Optional: Play a sound or show browser alert
          console.log("A driver just selected your donation!", pickupData);
          
          activePhase = 1; // Mark phase 1 starts!
          
          // --- Prepare Phase 1 Visualization ---
          if (donorMarker) {
              const startLat = pickupData.sim_start_lat || (truckMarker ? truckMarker.getPosition().lat() : 19.1136);
              const startLng = pickupData.sim_start_lng || (truckMarker ? truckMarker.getPosition().lng() : 72.8697);
              
              if (!truckMarker) {
                  truckMarker = new google.maps.Marker({
                      position: { lat: startLat, lng: startLng },
                      map: map,
                      title: "Driver approaching!",
                      icon: {
                          url: "https://maps.gstatic.com/mapfiles/ms2/micons/truck.png",
                          scaledSize: new google.maps.Size(40, 40)
                      },
                      zIndex: 1000
                  });
              } else {
                  truckMarker.setPosition({ lat: startLat, lng: startLng });
              }
              document.getElementById("dist-away").innerText = "Driver is moving!";
              document.getElementById("floating-dist").innerText = "Driver is moving!";
          }

        } else {
          console.log("FAILED MATCH! The selected ID was", pickupData.id, "but my IDs are:", myDonations.map(d => d.id));
        }
      });
      
      // Socket Event for Phase 2 (Order Picked Up)!
      socket.on("orderPickedUp", (data) => {
        if(activePickupId !== null && data.id === activePickupId && activeMyDonation) {
            console.log("Phase 2 Triggered: Headed to NGO!", activeMyDonation);
            activePhase = 2; // Transition phase state!
            
            document.getElementById("floating-dist").innerHTML = "Headed to NGO...";
            document.getElementById("eta").innerHTML = "En Route to NGO";
            document.querySelector('.tracker-header h2').innerText = "En Route to NGO";
            document.querySelector('.tracker-header h2').style.color = "var(--primary)";
            
            // Re-label sidebar item
            const itemTitle = document.getElementById("donation-title-" + activePickupId);
            if(itemTitle) itemTitle.innerHTML = `En Route to ${activeMyDonation.orphanage_name}`;
        }
      });
      
      // Socket Event for Successful Drop-off!
      socket.on("deliveryCompleted", (data) => {
        if(activePickupId !== null && data.id === activePickupId) {
            console.log("Phase 3: Delivery Successfully Completed!");
            activePhase = 3;
            document.getElementById("dist-away").innerText = "Drop-off Completed!";
            document.getElementById("floating-dist").innerHTML = "<span style='color:#4CAF50;'>Drop-off Completed!</span>";
            document.getElementById("eta").innerHTML = "✅ Delivered";
            
            const panelHeader = document.querySelector('.tracker-header h2');
            if (panelHeader) {
                panelHeader.innerText = "Delivered! 🎉";
                panelHeader.style.color = "#4CAF50";
            }
            
            // Remove the active request card from sidebar
            const itemTitle = document.getElementById("donation-title-" + activePickupId);
            if (itemTitle) itemTitle.closest('.product-card').remove();

            // Show the glorious success overlay!
            showSuccessOverlay();
        }
      });

      // 3. LISTEN FOR REAL-TIME SIMULATION DATA FROM DRIVER
      socket.on("receiveLocation", (data) => {
        if (!activePickupId) return;

        if (data.lat && data.lng) {
          const driverPos = { lat: parseFloat(data.lat), lng: parseFloat(data.lng) };

          if (!truckMarker) {
            truckMarker = new google.maps.Marker({
              position: driverPos,
              map: map,
              title: "Driver approaching!",
              icon: {
                url: "https://maps.gstatic.com/mapfiles/ms2/micons/truck.png",
                scaledSize: new google.maps.Size(40, 40)
              },
              zIndex: 1000
            });
          } else {
            truckMarker.setPosition(driverPos);
          }

          // === PHASE 1 VISUALS (Driver -> Donor) ===
          if (activePhase === 1 && donorMarker) {
            const myPos = donorMarker.getPosition();
            if (connectionLine) connectionLine.setMap(null);

            connectionLine = new google.maps.Polyline({
              path: [myPos, driverPos],
              geodesic: true,
              strokeColor: '#FF8c00',
              strokeOpacity: 0.8,
              strokeWeight: 4,
              icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_OPEN_ARROW, scale: 3 }, offset: '50%' }]
            });
            connectionLine.setMap(map);
            
            // Reframe map smoothly but prevent stutter by limiting bound fitting
            boundsLimiter++;
            if (boundsLimiter % 5 === 0) {
               const bounds = new google.maps.LatLngBounds();
               bounds.extend(myPos);
               bounds.extend(driverPos);
               map.fitBounds(bounds, { padding: 80 });
            }
            
            // Use haversine or straight-line distance fallback
            const distKm = (google.maps.geometry.spherical.computeDistanceBetween(driverPos, myPos) / 1000).toFixed(1);
            if (distKm < 0.1) {
                document.getElementById("dist-away").innerText = "Driver at Doorstep";
                document.getElementById("floating-dist").innerHTML = "<span style='color:#FF8c00;'>Waiting for Driver to Confirm...</span>";
                document.getElementById("eta").innerHTML = "At Doorstep";
                
                const panelHeader = document.querySelector('.tracker-header h2');
                if (panelHeader && !panelHeader.innerText.includes("Arrived")) {
                    panelHeader.innerText = "Driver Arrived";
                    panelHeader.style.color = "#FF8c00";
                }
            } else {
                document.getElementById("dist-away").innerText = `${distKm} km left`;
                document.getElementById("floating-dist").innerText = `${distKm} km left`;
            }
          }
          // === PHASE 2 VISUALS (Donor -> NGO) ===
          else if (activePhase === 2 && activeMyDonation) {
            const ngoPos = new google.maps.LatLng(
               parseFloat(activeMyDonation.ngo_lat) || 19.07, 
               parseFloat(activeMyDonation.ngo_lng) || 72.87
            );
            
            if (connectionLine) connectionLine.setMap(null);

            connectionLine = new google.maps.Polyline({
              path: [driverPos, ngoPos],
              geodesic: true,
              strokeColor: '#4CAF50',
              strokeOpacity: 0.8,
              strokeWeight: 4,
              icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_OPEN_ARROW, scale: 3 }, offset: '50%' }]
            });
            connectionLine.setMap(map);

            boundsLimiter++;
            if (boundsLimiter % 5 === 0) {
               const bounds = new google.maps.LatLngBounds();
               bounds.extend(ngoPos);
               bounds.extend(driverPos);
               map.fitBounds(bounds, { padding: 80 });
            }
            
            const distKm = (google.maps.geometry.spherical.computeDistanceBetween(driverPos, ngoPos) / 1000).toFixed(1);
            document.getElementById("dist-away").innerText = `${distKm} km to NGO`;
            document.getElementById("floating-dist").innerText = `${distKm} km to NGO`;
          }
          
          // Throttled ETA calls to prevent spamming Google Maps
          if (boundsLimiter % 40 === 0) {
             let destLat = activePhase === 1 ? donorMarker.getPosition().lat() : parseFloat(activeMyDonation.ngo_lat) || 19.07;
             let destLng = activePhase === 1 ? donorMarker.getPosition().lng() : parseFloat(activeMyDonation.ngo_lng) || 72.87;
             fetchETA(`${driverPos.lat},${driverPos.lng}`, `${destLat},${destLng}`);
          }
        }

          const driverPos = { lat: parseFloat(data.lat), lng: parseFloat(data.lng) };

          if (!truckMarker) {
            truckMarker = new google.maps.Marker({
              position: driverPos,
              map: map,
              title: "Driver approaching!",
              icon: {
                url: "https://maps.gstatic.com/mapfiles/ms2/micons/truck.png",
                scaledSize: new google.maps.Size(40, 40)
              },
              zIndex: 1000
            });
          } else {
            truckMarker.setPosition(driverPos);
          }

          // === PHASE 1 VISUALS (Driver -> Donor) ===
          if (activePhase === 1 && donorMarker) {
            const myPos = donorMarker.getPosition();
            if (connectionLine) connectionLine.setMap(null);

            connectionLine = new google.maps.Polyline({
              path: [myPos, driverPos],
              geodesic: true,
              strokeColor: '#FF8c00',
              strokeOpacity: 0.8,
              strokeWeight: 4,
              icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_OPEN_ARROW, scale: 3 }, offset: '50%' }]
            });
            connectionLine.setMap(map);
            
            // Reframe map smoothly but prevent stutter by limiting bound fitting
            boundsLimiter++;
            if (boundsLimiter % 5 === 0) {
               const bounds = new google.maps.LatLngBounds();
               bounds.extend(myPos);
               bounds.extend(driverPos);
               map.fitBounds(bounds, { padding: 80 });
            }
            
            // Use haversine or straight-line distance fallback
            const distKm = (google.maps.geometry.spherical.computeDistanceBetween(driverPos, myPos) / 1000).toFixed(1);
            if (distKm < 0.1) {
                document.getElementById("dist-away").innerText = "Driver at Doorstep";
                document.getElementById("floating-dist").innerHTML = "<span style='color:#FF8c00;'>Waiting for Driver to Confirm...</span>";
                document.getElementById("eta").innerHTML = "At Doorstep";
                
                const panelHeader = document.querySelector('.tracker-header h2');
                if (panelHeader && !panelHeader.innerText.includes("Arrived")) {
                    panelHeader.innerText = "Driver Arrived";
                    panelHeader.style.color = "#FF8c00";
                }
            } else {
                document.getElementById("dist-away").innerText = `${distKm} km left`;
                document.getElementById("floating-dist").innerText = `${distKm} km left`;
            }
          }
          // === PHASE 2 VISUALS (Donor -> NGO) ===
          else if (activePhase === 2 && activeMyDonation) {
            const ngoPos = new google.maps.LatLng(
               parseFloat(activeMyDonation.ngo_lat) || 19.07, 
               parseFloat(activeMyDonation.ngo_lng) || 72.87
            );
            
            if (connectionLine) connectionLine.setMap(null);

            connectionLine = new google.maps.Polyline({
              path: [driverPos, ngoPos],
              geodesic: true,
              strokeColor: '#4CAF50',
              strokeOpacity: 0.8,
              strokeWeight: 4,
              icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_OPEN_ARROW, scale: 3 }, offset: '50%' }]
            });
            connectionLine.setMap(map);

            boundsLimiter++;
            if (boundsLimiter % 5 === 0) {
               const bounds = new google.maps.LatLngBounds();
               bounds.extend(ngoPos);
               bounds.extend(driverPos);
               map.fitBounds(bounds, { padding: 80 });
            }
            
            const distKm = (google.maps.geometry.spherical.computeDistanceBetween(driverPos, ngoPos) / 1000).toFixed(1);
            document.getElementById("dist-away").innerText = `${distKm} km to NGO`;
            document.getElementById("floating-dist").innerText = `${distKm} km to NGO`;
          }
          
          // Throttled ETA calls to prevent spamming Google Maps
          if (boundsLimiter % 40 === 0) {
             let destLat = activePhase === 1 ? donorMarker.getPosition().lat() : parseFloat(activeMyDonation.ngo_lat) || 19.07;
             let destLng = activePhase === 1 ? donorMarker.getPosition().lng() : parseFloat(activeMyDonation.ngo_lng) || 72.87;
             fetchETA(`${driverPos.lat},${driverPos.lng}`, `${destLat},${destLng}`);
          }
        }
      });

      // 3. Track DONOR'S Static/Live Location (High Accuracy)
      if (navigator.geolocation) {
        navigator.geolocation.watchPosition(
          (position) => {
            const userLat = position.coords.latitude;
            const userLng = position.coords.longitude;
            const userPos = { lat: userLat, lng: userLng };

            document.getElementById("status").innerHTML = `<span class="badge">Live</span> Active at [${userLat.toFixed(4)}, ${userLng.toFixed(4)}]`;

            if (!donorMarker) {
              donorMarker = new google.maps.Marker({
                position: userPos,
                map: map,
                title: "My Home",
                icon: "http://maps.google.com/mapfiles/ms/icons/blue-dot.png"
              });
              map.panTo(userPos); // strictly focus map on user when found first time
              map.setZoom(14);
            } else {
              donorMarker.setPosition(userPos);
            }

            // Re-draw line if moving
            if (connectionLine && connectionLine.connectedMarkerId) {
              const targetMarker = pickupMarkers[connectionLine.connectedMarkerId];
              if (targetMarker) {
                connectionLine.setPath([userPos, targetMarker.getPosition()]);
              }
            }

          },
          (error) => {
            document.getElementById("status").innerHTML = `<span style="color:red">Error: ${error.message}</span>`;
          },
          {
            enableHighAccuracy: true,
            maximumAge: 0,
            timeout: 10000
          }
        );
      } else {
        document.getElementById("status").innerText = "Geolocation not supported.";
      }
    }

    function renderProducts(pickups) {
      const container = document.getElementById("products-container");
      if (!pickups || pickups.length === 0) {
        container.innerHTML = `<div style="text-align:center; padding: 20px; color: #888; font-size: 14px;">No active donations found.</div>`;
        return;
      }

      let html = '';
      pickups.forEach(p => {
        html += `
              <div class="product-card" onclick="focusOnDonorMap()">
                <div class="product-title" id="donation-title-${p.id}">
                  #${p.id} - ${escapeHtml(p.donor_name)}
                  <!-- The 'En Route' badge will be dynamically injected here when driver selects it -->
                </div>
                <div class="product-detail">
                  🏠 ${escapeHtml(p.donor_address || 'Address not listed')}
                </div>
                <div class="product-detail" style="font-weight:600; color:var(--primary);">
                  🏢 Going To: ${escapeHtml(p.orphanage_name || 'Pending assignment')}
                </div>
              </div>
            `;
      });
      container.innerHTML = html;
    }

    function escapeHtml(unsafe) {
      if (!unsafe) return "";
      return unsafe.toString()
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    function focusOnDonorMap() {
      if (donorMarker) {
        map.panTo(donorMarker.getPosition());
        map.setZoom(15);
      }
    }

    // 4. Fetch ETA logically separating ETA UI and Distance UI
    function fetchETA(origin, destination) {
      fetch(`${backendUrl}/pickup/eta?origin=${origin}&destination=${destination}`)
        .then(res => {
          if (!res.ok && res.status !== 400 && res.status !== 500) {
            throw new Error("Network error or backend down");
          }
          return res.json();
        })
        .then(data => {
          // Google API response might be 200 OK but with "status": "REQUEST_DENIED"
          if (data.status === "REQUEST_DENIED" || data.status === "OVER_QUERY_LIMIT" || data.error_message) {
            const errMsg = data.error_message || "API Key issue.";
            document.getElementById("eta").innerHTML = `<span style="color:red; font-size:13px;">Error: ${errMsg}</span>`;
            console.error("Google API Error:", errMsg);
            return;
          }

          if (data.error) {
            // Backend threw custom error
            document.getElementById("eta").innerHTML = `<span style="color:red; font-size:13px;">${data.error}</span>`;
            return;
          }

          if (data.rows && data.rows.length > 0 && data.rows[0].elements && data.rows[0].elements.length > 0) {
            const element = data.rows[0].elements[0];
            if (element.status === "OK") {
              const duration = element.duration.text;
              // ONLY update ETA display — do NOT touch dist-away during animation
              document.getElementById("eta").innerHTML = `<span class="highlight">${duration}</span> <span style="font-size:14px; color:#666;">Truck is routing..</span>`;
            } else {
              document.getElementById("eta").innerHTML = `<span style="color:#d35400;">Route not found (${element.status})</span>`;
            }
          } else {
            document.getElementById("eta").innerHTML = "ETA calculation failed.";
          }
        })
        .catch(err => {
          // Usually network failure (backend disconnected)
          console.error("Fetch ETA Error:", err);
          document.getElementById("eta").innerHTML = `<span style="color:red; font-size:13px;">Backend connection failed</span>`;
        });
    }
    // ============================================
    // SUCCESS OVERLAY FUNCTION
    // ============================================
    function showSuccessOverlay() {
      const overlay = document.getElementById('success-overlay');
      // Hide tracker panel and map lines
      document.getElementById('arriving-panel').style.display = 'none';
      if (connectionLine) connectionLine.setMap(null);
      if (truckMarker) truckMarker.setMap(null);

      // Launch confetti
      const container = document.getElementById('confetti-container');
      container.innerHTML = '';
      const colors = ['#4CAF50','#8BC34A','#CDDC39','#FF8c00','#FFB800','#2196F3','#E91E63'];
      for (let i = 0; i < 60; i++) {
        const dot = document.createElement('div');
        dot.className = 'confetti-dot';
        dot.style.cssText = `
          left: ${Math.random() * 100}%;
          background: ${colors[Math.floor(Math.random() * colors.length)]};
          width: ${6 + Math.random() * 10}px;
          height: ${6 + Math.random() * 10}px;
          border-radius: ${Math.random() > 0.5 ? '50%' : '2px'};
          animation-duration: ${2 + Math.random() * 3}s;
          animation-delay: ${Math.random() * 1.5}s;
        `;
        container.appendChild(dot);
      }

      // Show overlay with fade-in
      overlay.classList.add('show');
      requestAnimationFrame(() => {
        requestAnimationFrame(() => { overlay.classList.add('visible'); });
      });

      // Auto reset after 5s
      setTimeout(() => {
        overlay.classList.remove('visible');
        setTimeout(() => {
          overlay.classList.remove('show');

          // Clean up state
          truckMarker = null;
          activePickupId = null;
          activeMyDonation = null;
          animationActive = false;

          // Show radar waiting overlay again
          const radar = document.getElementById('waiting-overlay');
          radar.style.display = 'flex';
          void radar.offsetWidth;
          radar.style.opacity = '1';

          // Refresh donation list
          fetch(`${backendUrl}/pickup/all`).then(r => r.json()).then(pickups => {
            myDonations = pickups;
            renderProducts(pickups);
          });
        }, 600);
      }, 5000);
    }
  