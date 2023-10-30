# TinyGo.nvim
This NeoVim plugin lets you configure Go's environment variables so that Go's LSP server
(i.e. `gopls`) offers accurate completions and suggestions.

Under the hood it basically parses the output of `go env`, `tinygo targets` and `tinygo target ...`
to then restart the attached `gopls` instance with the appropriate environment variables. As
of now, it relies on [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig) to restart the
attached `gopls` instance, but it can also be made to cooperate with the stock Nvim LSP API
documented [here](https://neovim.io/doc/user/lsp.html).

The plugin is loosely based on a preexisting one written in Vim Script:
[`sago35/tinygo.vim`](https://github.com/sago35/tinygo.vim). Thanks a lot for the guidance!

The initial (and authoritative) source of information on what needs to be configured for TinyGo's
correct integration with `gopls` can be found [here](https://tinygo.org/docs/guides/ide-integration/).

Aside from that, in writing this (our very first) plugin we found the following sites and documentation
to be extremely helpful:

- [Neovim: Plugins to get started](https://vonheikemen.github.io/devlog/tools/neovim-plugins-to-get-started/): Great discussion
  on the anatomy of Neovim plugins and how they are structured.

- [Unofficial Neovim Lua Guide](https://github.com/nanotee/nvim-lua-guide): A great primer on using Lua within Neovim.

- [Linode Neovim Tutorial](https://www.linode.com/docs/guides/write-a-neovim-plugin-with-lua/): Despite the website being
   very choppy (at least on Safari) and throwing some Vim Script in the mix, this tutorial presents a nice overall structure
   of what a Neovim plugin looks like.

- [Lua 5.1 Reference](http://www.lua.org/manual/5.1/manual.html): For everything Lua, nothing beats the official reference.

- [Neovim LSP documentation](https://neovim.io/doc/user/lsp.html): The official documentation on Neovim and its LSP implementation
  sheds a lot of light on what makes LSPs tick. However, this is mostly abstracted away in our case by `nvim-lspconfig`.

- [Neovim builtin documentation](https://neovim.io/doc/user/builtin.html): The official documentation on builtin functions we can
  invoke through `vim.fn` from Lua. Things like `json_decode` proved to be extremely useful.

- [Neovim Lua documentation](https://neovim.io/doc/user/lua.html): The official documentation on Lua within Neovim helps one come
  to terms with how everything is structured as well as the goodies (i.e. standard library, APIs and such) one can rely on.

- [Official Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html): Pretty much like its unofficial counterpart, this guide
  offers a more hands-on experience on how to leverage Lua in the context of Neovim.

- [Lspconfig documentation](https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/doc/lspconfig.txt): This documentation
  (accessible through `:h lspconfig` within Neovim) offers some insights into how LSP servers are configured. For instance, it
  explains how `lspconfig.gopls.setup` actually restarts the LSP instance attached to a buffer, which made our life that much easier!

## Dependencies
As previously stated, this plugin relies on `nvim-lspconfig` to manage the attached LSP instance. However, this plugin can instead
resort to 'pure' API calls if this were to prove an obstacle. Given the pervasiveness of `nvim-lspconfig` that is unlikely to happen,
but it is nice to know we can count on some wiggle room!

## Installation
This plugin can be installed through regular plugin manages. I use [`packer.nvim`](https://github.com/wbthomason/packer.nvim),
so it's the example we'll provide. The rest should be rather similar: this plugin requires no settings!

```lua
use {
    "pcolladosoto/tinygo.nvim",
    config = function() require("tinygo").setup() end
}
```

## Usage
This plugin provides three different user commands:

- `:TinyGoSetTarget <target-name>`: This command configures the target name passed as a parameter. TABbing will
  display a list with available targets, including `original`. This special target will leave the Go
  environment as it was before configuring any other target.

- `:TinyGoTargets`: This command will simply list available TinyGo targets, excluding `original`.

- `:TinyGoEnv`: This commmand prints the currently configured target, `GOROOT` and `GOFLAGS`.

I hope you find this useful!
