const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = 3000;
// Uses the Docker Compose service name 'backend' to resolve the URL
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:5000/api/submit';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// Add this explicit fallback to guarantee index.html is served
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Route to handle form submission from client-side and push to Flask
app.post('/send-to-backend', async (req, res) => {
    try {
        const response = await axios.post(BACKEND_URL, req.body);
        res.status(200).json(response.data);
    } catch (error) {
        console.error("Error communicating with Flask backend:", error.message);
        res.status(500).json({ status: "error", message: "Failed to connect to backend service." });
    }
});

app.listen(PORT, () => {
    console.log(`Frontend UI running on http://localhost:${PORT}`);
});