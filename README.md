# TinyGo.nvim
This NeoVim plugin lets you configure Go's environment variables so that Go's LSP server
(i.e. `gopls`) offers accurate completions and suggestions. A sane and working TinyGo
installation is of course a prerequisite for the plugin to work!

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

Note this repository 'lives' locally on our development machine over at:

    ~/.local/share/nvim/site/pack/packer/start/tinygo.nvim

That's because it's been installed with [packer.nvim](https://github.com/wbthomason/packer.nvim) and that's where stuff goes...

## Dependencies
As previously stated, this plugin relies on `nvim-lspconfig` to manage the attached LSP instance. However, this plugin can instead
resort to 'pure' API calls if this were to prove an obstacle. Given the pervasiveness of `nvim-lspconfig` that is unlikely to happen,
but it is nice to know we can count on some wiggle room!

## Installation
This plugin can be installed through regular plugin managers.

### [Packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    "pcolladosoto/tinygo.nvim",
    config = function() require("tinygo").setup() end
}
```

### [Lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
    "pcolladosoto/tinygo.nvim",
    opts = {},
}
```

## Options
Additionally you can provide the following options.

- **`config_file`** [string]: Defines the path to a `json` config file. (default: `.tinygo.json`)
- **`cmd`** [string]: The TinyGo command that is used when executing. (default: `tinygo`)

## Usage
This plugin provides three different user commands:

- `:TinyGoSetTarget <target-name>`: This command configures the target name passed as a parameter. TABbing will
  display a list with available targets, including `original`. This special target will leave the Go
  environment as it was before configuring any other target.

- `:TinyGoTargets`: This command will simply list available TinyGo targets, excluding `original`.

- `:TinyGoEnv`: This commmand prints the currently configured target, `GOROOT` and `GOFLAGS`.

- `:TinyGoFlash ?<target-name>`: This commmand flashes the code to the provided target. If no target is given the
   currently set target is used.

- `:TinyGoMonitor <...>`: This command opens a floating window which streams the output of `tinygo monitor`.
  You can provide additional cli flags to the command by appending them.

Alternatively you can add a file (default: `.tinygo.json`) into your cwd and set your target there.
This plugin automatically loads this config file on startup and dynamically reloads when the config
file is changed.

Here is an example of the config file and its possible options.

```json
{
  "target": "pico"
}
```

- **`target`** [string]: Auto sets the target to the provided value. Has to be one of 'tinygo targets' results.

I hope you find this useful!
