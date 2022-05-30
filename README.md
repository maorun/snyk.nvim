
# WIP

atm. only [Snyk Code](https://docs.snyk.io/products/snyk-code) is integrated

## @ToDo
- [Snyk Infrastructure as Code](https://docs.snyk.io/products/snyk-infrastructure-as-code)
- [Snyk Container](https://docs.snyk.io/products/snyk-container)
- [Snyk Open Source](https://docs.snyk.io/products/snyk-open-source)

## Requirements
[Getting started with Snyk](https://docs.snyk.io/getting-started)

### The following requirements should be implemented in the plugin, but atm. you are responsible for these steps
- [Installation of Snyk CLI](https://docs.snyk.io/snyk-cli/install-the-snyk-cli)
eg:
```bash
npm install -g snyk
```
- (once)
```bash
snyk auth
```

## Installation
eg:
[vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'maorun/snyk.nvim'
```

## Usage

```lua
require('maorun.snyk').setup()
```

## Troubleshooting
Q: Why are my files not scanned?

A: [Code language and framework support](https://docs.snyk.io/products/snyk-code/snyk-code-language-and-framework-support)
