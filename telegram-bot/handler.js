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
    }

    return { statusCode: 200, body: "ok" };
  } catch (err) {
    console.error("Handler error:", err);
    return { statusCode: 200, body: "ok" };
  }
};
