
const { handler } = require("./handler");

// Mock environment variables if not set
process.env.ALLOWED_USERNAME = process.env.ALLOWED_USERNAME || "yadidians";
process.env.TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "fake-token";

async function testStartCommand() {
    console.log("Testing /start command...");
    const event = {
        body: JSON.stringify({
            message: {
                from: { username: "yadidians" },
                chat: { id: 123456789 },
                text: "/start",
            },
        }),
    };

    try {
        const result = await handler(event);
        console.log("Result:", result);
    } catch (error) {
        console.error("Handler execution failed:", error);
    }
}

testStartCommand();
