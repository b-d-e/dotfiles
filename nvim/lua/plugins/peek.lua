-- Live markdown preview in a floating webview window (toppair/peek.nvim).
-- Needs `deno` on PATH (Brewfile) — lazy builds the bundled preview app with it.

---@type LazySpec
return {
  "toppair/peek.nvim",
  build = "deno task --quiet build:fast",
  ft = "markdown",
  opts = {
    auto_load = true, -- open the preview when entering a markdown buffer that already has one
    close_on_bdelete = true,
    syntax = true,
    theme = "dark",
    update_on_change = true,
    app = "webview", -- "webview" | "browser" | { "<path to browser>", "<args>" }
    filetype = { "markdown" },
    throttle_at = 200000, -- start throttling at ~200kB of markdown
    throttle_time = "auto",
  },
  config = function(_, opts)
    local peek = require "peek"
    peek.setup(opts)
    vim.api.nvim_create_user_command("PeekOpen", peek.open, { desc = "Open markdown preview" })
    vim.api.nvim_create_user_command("PeekClose", peek.close, { desc = "Close markdown preview" })
  end,
  keys = {
    {
      "<Leader>mp",
      function()
        local peek = require "peek"
        if peek.is_open() then
          peek.close()
        else
          peek.open()
        end
      end,
      ft = "markdown",
      desc = "Toggle markdown preview",
    },
  },
}
