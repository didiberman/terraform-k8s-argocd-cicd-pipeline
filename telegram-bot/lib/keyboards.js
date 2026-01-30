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
    [{ text: "🎨 Change App Color", callback_data: "color_menu" }],
  ],
};

const backMenu = {
  inline_keyboard: [[{ text: "Back to Menu", callback_data: "menu" }]],
};

const colorMenu = {
  inline_keyboard: [
    [
      { text: "🔵 Blue", callback_data: "set_color_blue" },
      { text: "🟢 Green", callback_data: "set_color_green" },
    ],
    [
      { text: "🔴 Red", callback_data: "set_color_red" },
      { text: "🍍 Pineapple", callback_data: "set_color_pineapple" },
    ],
    [
      { text: "🟣 Default Gradient", callback_data: "set_color_default" },
    ],
    [{ text: "🔙 Back to Menu", callback_data: "menu" }],
  ],
};

module.exports = { mainMenu, backMenu, colorMenu };
