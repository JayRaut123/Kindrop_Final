const axios = require('axios');

async function checkModels() {
  const apiKey = 'AIzaSyA8flA2E4drpKFOhLwvCecGvjWvYg2YctI';
  const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;

  try {
    const response = await axios.get(url);
    const models = response.data.models;
    const modelNames = models.map(m => m.name);
    console.log("Allowed models for this API Key:", modelNames.join(", "));
  } catch (error) {
    console.error("Error fetching models:", error.response ? error.response.data : error.message);
  }
}

checkModels();
