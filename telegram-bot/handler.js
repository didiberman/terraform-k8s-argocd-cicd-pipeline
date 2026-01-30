const telegram = require("./lib/telegram");
const github = require("./lib/github");
const k8s = require("./lib/k8s");
const keyboards = require("./lib/keyboards");

const ALLOWED_USERNAME = process.env.ALLOWED_USERNAME;

exports.handler = async (event) => {
  try {
    const body =
      typeof event.body === "string" ? JSON.parse(event.body) : event.body;

    // Handle message (e.g. /start)
    if (body.message) {
      const chatId = body.message.chat.id;
      const username = body.message.from?.username;
      if (ALLOWED_USERNAME && username !== ALLOWED_USERNAME) {
        return { statusCode: 200, body: "ok" };
      }

      const text = body.message.text || "";
      if (text === "/start") {
        await telegram.sendMessage(
          chatId,
          "*K8s Cluster Manager*\nChoose an action:",
          keyboards.mainMenu
        );
      }
      return { statusCode: 200, body: "ok" };
    }

    // Handle callback query (inline keyboard button press)
    if (body.callback_query) {
      const query = body.callback_query;
      const chatId = query.message.chat.id;
      const messageId = query.message.message_id;
      const action = query.data;

      const username = query.from?.username;

      if (ALLOWED_USERNAME && username !== ALLOWED_USERNAME) {
        return { statusCode: 200, body: "ok" };
      }

      await telegram.answerCallback(query.id);

      if (action === "menu") {
        await telegram.editMessage(
          chatId,
          messageId,
          "*K8s Cluster Manager*\nChoose an action:",
          keyboards.mainMenu
        );
        return { statusCode: 200, body: "ok" };
      }

      if (action === "deploy") {
        await telegram.editMessage(
          chatId,
          messageId,
          "Triggering *deploy*...",
          keyboards.backMenu
        );
        await github.dispatch("terraform_apply", chatId);
        return { statusCode: 200, body: "ok" };
      }

      if (action === "destroy") {
        await telegram.editMessage(
          chatId,
          messageId,
          "Triggering *destroy*...",
          keyboards.backMenu
        );
        await github.dispatch("terraform_destroy", chatId);
        return { statusCode: 200, body: "ok" };
      }

      if (action === "get_pods") {
        await telegram.editMessage(
          chatId,
          messageId,
          "Fetching pods..."
        );
        try {
          const pods = await k8s.getPods();
          await telegram.editMessage(
            chatId,
            messageId,
            `*Pods:*\n${pods}`,
            keyboards.backMenu
          );
        } catch (err) {
          console.error("Get Pods Error:", err);
          const msg =
            err.message === "K8s API request timed out"
              ? "Cluster is not reachable (timeout)."
              : "Could not fetch pods. Is the cluster running?";
          await telegram.editMessage(
            chatId,
            messageId,
            `*Error:* ${msg}`,
            keyboards.backMenu
          );
        }
        return { statusCode: 200, body: "ok" };
      }

      if (action === "get_nodes") {
        await telegram.editMessage(
          chatId,
          messageId,
          "Fetching nodes..."
        );
        try {
          const nodes = await k8s.getNodes();
          await telegram.editMessage(
            chatId,
            messageId,
            `*Nodes:*\n${nodes}`,
            keyboards.backMenu
          );
        } catch (err) {
          console.error("Get Nodes Error:", err);
          const msg =
            err.message === "K8s API request timed out"
              ? "Cluster is not reachable (timeout)."
              : "Could not fetch nodes. Is the cluster running?";
          await telegram.editMessage(
            chatId,
            messageId,
            `*Error:* ${msg}`,
            keyboards.backMenu
          );
        }
        return { statusCode: 200, body: "ok" };
      }

      // Handle Color Menu
      if (action === "color_menu") {
        await telegram.editMessage(
          chatId,
          messageId,
          "🎨 *Choose App Background Color*:",
          keyboards.colorMenu
        );
        return { statusCode: 200, body: "ok" };
      }

      // Handle specific color selection
      if (action.startsWith("set_color_")) {
        const colorMap = {
          "set_color_blue": "#3b82f6",
          "set_color_green": "#22c55e",
          "set_color_red": "#ef4444",
          "set_color_pineapple": "#fbbf24",
          "set_color_default": "" // Empty string resets to default gradient
        };

        const colorCode = colorMap[action];

        await telegram.editMessage(
          chatId,
          messageId,
          `Triggering update to *${action.replace("set_color_", "").toUpperCase()}*... 🌈`,
          keyboards.backMenu
        );

        // Dispatch with payload
        await github.dispatch("update_color", chatId, { color: colorCode });

        return { statusCode: 200, body: "ok" };
      }
    }

    return { statusCode: 200, body: "ok" };
  } catch (err) {
    console.error("Critical Handler Error:", err);
    return { statusCode: 200, body: "ok" };
  }
};
