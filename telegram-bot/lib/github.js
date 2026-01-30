const https = require("https");

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPO = process.env.GITHUB_REPO; // e.g. "yadid/k8s"

function dispatch(eventType, chatId) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      event_type: eventType,
      client_payload: { chat_id: String(chatId) },
    });

    const url = new URL(
      `https://api.github.com/repos/${GITHUB_REPO}/dispatches`
    );
    const req = https.request(
      url,
      {
        method: "POST",
        headers: {
          Authorization: `token ${GITHUB_TOKEN}`,
          Accept: "application/vnd.github.v3+json",
          "User-Agent": "k8s-telegram-bot",
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(data),
        },
      },
      (res) => {
        let chunks = "";
        res.on("data", (c) => (chunks += c));
        res.on("end", () => resolve({ statusCode: res.statusCode, body: chunks }));
      }
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
}

module.exports = { dispatch };
