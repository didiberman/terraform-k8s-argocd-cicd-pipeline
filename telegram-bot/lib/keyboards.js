const mainMenu = {
  inline_keyboard: [
    [
      { text: "Deploy", callback_data: "deploy" },
      { text: "Destroy", callback_data: "destroy" },
    ],
    [
      { text: "Get Pods", callback_data: "get_pods" },
      { text: "Get Nodes", callback_data: "get_nodes" },
    ],
  ],
};

const backMenu = {
  inline_keyboard: [[{ text: "Back to Menu", callback_data: "menu" }]],
};

module.exports = { mainMenu, backMenu };
