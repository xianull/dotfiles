return {
  "folke/flash.nvim",
  event = "VeryLazy",
  keys = {
    { "s", mode = { "n", "v" }, function() require("flash").jump() end, desc = "Flash jump" },
    { "S", mode = { "n", "v" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Flash remote" },
  },
}
