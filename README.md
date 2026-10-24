## Requirements
- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Node.js and npm
- [Snyk CLI](https://support.snyk.io/hc/en-us/articles/360381182825-Snyk-CLI-Getting-Started) (available in `$PATH` or installed via `npm install`)
- [Getting started with Snyk](https://docs.snyk.io/getting-started)

## Installation
eg:
[vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'nvim-lua/plenary.nvim'
Plug('maorun/snyk.nvim', { [ 'do' ]= 'npm install'  })
```

## Usage

```lua
require('maorun.snyk').setup()
```

## Troubleshooting
Q: Why are my files not scanned?

A: [Code language and framework support](https://docs.snyk.io/products/snyk-code/snyk-code-language-and-framework-support)
