// Visitor counter — wired to API Gateway + Lambda + DynamoDB in Phase 2.
// Replace API_URL with your API Gateway endpoint once it's deployed.

const API_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/count";

async function updateVisitorCount() {
  const el = document.getElementById("visitor-count");
  try {
    const response = await fetch(API_URL);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    el.textContent = data.count;
  } catch (err) {
    // Silently fail — the counter is non-critical UI
    console.warn("Visitor counter unavailable:", err.message);
  }
}

updateVisitorCount();
