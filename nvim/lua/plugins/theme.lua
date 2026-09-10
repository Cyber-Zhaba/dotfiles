-- Colorscheme.
--
-- On an Omarchy box the system owns the theme: `omarchy-theme-set` repoints
-- ~/.local/state/omarchy/current/theme, and the generated neovim.lua there is
-- the spec to use -- so load it and let theme switching keep working.
--
-- Anywhere else that path does not exist, and the pinned spec below applies:
-- aether v3 with the palette this environment was built around.
local omarchy_theme = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
if (vim.uv or vim.loop).fs_stat(omarchy_theme) then
  return dofile(omarchy_theme)
end

return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#222222",
        dark_bg = "#191919",
        darker_bg = "#121212",
        lighter_bg = "#2c2c2c",

        fg = "#c2c2b0",
        dark_fg = "#555555",
        light_fg = "#8a8a7e",
        bright_fg = "#c2c2b0",
        muted = "#666666",

        red = "#685742",
        yellow = "#b36d43",
        orange = "#8d6242",
        green = "#5f875f",
        cyan = "#c9a554",
        blue = "#78824b",
        magenta = "#bb7744",
        brown = "#463121",

        bright_red = "#685742",
        bright_yellow = "#b36d43",
        bright_green = "#5f875f",
        bright_cyan = "#c9a554",
        bright_blue = "#78824b",
        bright_magenta = "#bb7744",

        accent = "#78824b",
        cursor = "#c2c2b0",
        foreground = "#c2c2b0",
        background = "#222222",
        selection = "#383838",
        selection_foreground = "#c2c2b0",
        selection_background = "#383838",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
