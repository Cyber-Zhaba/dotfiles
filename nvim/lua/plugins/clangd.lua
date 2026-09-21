-- Используем системный clangd (пакет clang), а не сборку из mason:
-- он знает include-пути установленного gcc/libstdc++.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          mason = false,
        },
      },
    },
  },
}
