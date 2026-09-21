-- ~/.config/nvim/lua/plugins/asm.lua
-- LSP + подсветка для ассемблера (LazyVim)
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        asm_lsp = {
          -- диагностика, автодополнение мнемоник и hover-справка по x86
          filetypes = { "asm", "s", "S", "nasm", "vmasm" },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "asm" })
    end,
  },
  {
    -- .asm по умолчанию определяется как masm; для NASM-файлов включаем nasm-синтаксис
    "LazyVim/LazyVim",
    opts = function()
      vim.g.asmsyntax = "nasm"
      vim.filetype.add({
        extension = { asm = "asm", inc = "asm", nasm = "asm" },
      })
    end,
  },
}
