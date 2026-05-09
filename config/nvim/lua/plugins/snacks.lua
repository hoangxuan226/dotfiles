local is_wsl = vim.fn.has("wsl") == 1

return {
  {
    "folke/snacks.nvim",
    config = function(_, opts)
      require("snacks").setup(opts)

      -- Apply image rendering fixes
      if is_wsl then
        require("config.snacks.fix-image-preview")() -- last checked: commit a049339328e2599ad6e85a69fa034ac501e921b2
        require("config.snacks.fix-picker-ghost-image")()
        require("config.snacks.improve-image-cpu")()
      end
    end,
    opts = {
      dashboard = {
        preset = {
          header = [[
          _____                    _____                    _____          
         /\    \                  /\    \                  /\    \         
        /::\    \                /::\____\                /::\    \        
       /::::\    \              /:::/    /               /::::\    \       
      /::::::\    \            /:::/    /               /::::::\    \      
     /:::/\:::\    \          /:::/    /               /:::/\:::\    \     
    /:::/__\:::\    \        /:::/    /               /:::/  \:::\    \    
   /::::\   \:::\    \      /:::/    /               /:::/    \:::\    \   
  /::::::\   \:::\    \    /:::/    /      _____    /:::/    / \:::\    \  
 /:::/\:::\   \:::\ ___\  /:::/____/      /\    \  /:::/    /   \:::\ ___\ 
/:::/__\:::\   \:::|    ||:::|    /      /::\____\/:::/____/  ___\:::|    |
\:::\   \:::\  /:::|____||:::|____\     /:::/    /\:::\    \ /\  /:::|____|
 \:::\   \:::\/:::/    /  \:::\    \   /:::/    /  \:::\    /::\ \::/    / 
  \:::\   \::::::/    /    \:::\    \ /:::/    /    \:::\   \:::\ \/____/  
   \:::\   \::::/    /      \:::\    /:::/    /      \:::\   \:::\____\    
    \:::\  /:::/    /        \:::\__/:::/    /        \:::\  /:::/    /    
     \:::\/:::/    /          \::::::::/    /          \:::\/:::/    /     
      \::::::/    /            \::::::/    /            \::::::/    /      
       \::::/    /              \::::/    /              \::::/    /       
        \::/____/                \::/____/                \::/____/        
]],
        },
      },
      -- image = {
      -- inline = false,
      -- enabled = false,
      -- formats = {},
      -- },
      terminal = {
        win = {
          position = "float",
          height = 0.7,
          width = 0.7,
          border = "rounded",
        },
      },
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
          },
          files = {
            hidden = true,
            ignored = true,
          },
          grep = {
            hidden = true,
            ignored = true,
          },
        },
      },
    },
  },
}
