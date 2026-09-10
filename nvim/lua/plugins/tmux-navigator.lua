return {
  "christoomey/vim-tmux-navigator",
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to Left Window (tmux/nvim)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to Lower Window" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to Upper Window" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to Right Window" },
    { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Go to Previous Window" },
  },
}
