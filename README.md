
# WIP

atm. only [Snyk Code](https://docs.snyk.io/products/snyk-code) is integrated

and [Snyk Infrastructure as Code](https://docs.snyk.io/products/snyk-infrastructure-as-code) only for YAML files


## Requirements
[Getting started with Snyk](https://docs.snyk.io/getting-started)

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
