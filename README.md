# vim-popup-agent

A Vim9 plugin that opens an interactive AI chat terminal in a floating popup window. Supports Claude, GitHub Copilot, and OpenAI Codex out of the box. Closing the popup hides it — the terminal session keeps running in the background and reopens where you left off. The popup also remembers its last position.

<img width="480" height="330" alt="img-1116" src="https://github.com/user-attachments/assets/0d92895c-e8fd-4527-9628-16f08da033d2" />


## Requirements

- Vim 8.2+ (compiled with `+terminal` and `+popupwin`)
- The CLI tool for whichever agent(s) you want to use (see [Agent Setup](#agent-setup))

> **Note:** This plugin uses Vim9 script and Vim's native popup + terminal APIs. It does **not** work in Neovim.

Check your Vim supports the required features:

```vim
:echo has('terminal') && has('popupwin')
```

Should print `1`.

## Installation

**vim-plug**
```vim
Plug 'myneid/vim-popup-agent'
```

**packer.nvim** — not applicable (Vim only)

**Vundle**
```vim
Plugin 'myneid/vim-popup-agent'
```

**Native packages**
```sh
git clone https://github.com/myneid/vim-popup-agent \
    ~/.vim/pack/plugins/start/vim-popup-agent
```

## Quick Start

```vim
:Agent           " open the default agent (claude)
:Agent claude    " open Claude
:Agent copilot   " open GitHub Copilot chat
:Agent codex     " open OpenAI Codex
```

Or press `<leader>a` to open the default agent.

Tab-completion works on the agent name argument.

## Usage

| Action | How |
|--------|-----|
| Open default agent | `<leader>a` or `:Agent` |
| Open specific agent | `:Agent claude` / `:Agent copilot` / `:Agent codex` |
| Hide popup (keep session) | `:w` inside the popup, `:AgentHide`, or click the `×` button |
| Reopen hidden popup | `<leader>a` or `:Agent` — resumes the same session |
| Close session | Exit the CLI normally (e.g. `/exit`, `Ctrl-D`) — the popup closes too |
| Move popup | Click and drag the title bar |
| Resize popup | Drag the popup edges |

The popup reopens at its last position. Position resets to screen-center on a fresh Vim session.

## Configuration

Add any of these to your `vimrc`:

```vim
" Which agent opens with :Agent or <leader>a  (default: 'claude')
let g:popup_agent_default = 'claude'

" Popup dimensions in columns/lines  (defaults: 100 × 30)
let g:popup_agent_width  = 100
let g:popup_agent_height = 30

" Disable the default <leader>a mapping
let g:popup_agent_no_maps = 1

" Override or extend agent commands
" Keys can replace built-ins or add new names
let g:popup_agent_commands = {
    \ 'claude': ['claude', '--model', 'claude-opus-4-7'],
    \ 'gpt':    ['sgpt', '--repl', 'temp'],
    \ }
```

### Custom key mapping

```vim
" Disable the default map first
let g:popup_agent_no_maps = 1

" Then bind however you like
nmap <C-a> <Plug>(popup-agent-open)
nmap <C-x> <Plug>(popup-agent-hide)

" Or bind individual agents
nnoremap <leader>ac <Cmd>Agent claude<CR>
nnoremap <leader>ap <Cmd>Agent copilot<CR>
nnoremap <leader>ax <Cmd>Agent codex<CR>
```

## Agent Setup

### Claude

Install the [Claude CLI](https://docs.anthropic.com/en/docs/claude-code):

```sh
npm install -g @anthropic-ai/claude-code
claude   # authenticate on first run
```

### GitHub Copilot (`gh copilot chat`)

Install the GitHub CLI and the Copilot extension:

```sh
brew install gh          # or your OS package manager
gh extension install github/gh-copilot
gh auth login            # authenticate
```

### OpenAI Codex

Install the [Codex CLI](https://github.com/openai/codex):

```sh
npm install -g @openai/codex
export OPENAI_API_KEY=sk-...   # add to your shell profile
codex                          # verify it starts
```

## Adding a Custom Agent

Any CLI that runs interactively in a terminal works:

```vim
let g:popup_agent_commands = {
    \ 'aider':  ['aider', '--no-auto-commits'],
    \ 'chatgpt': ['chatgpt'],
    \ }
```

Then `:Agent aider` opens it.

## License

MIT
