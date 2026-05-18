vim9script

if exists('g:loaded_popup_agent') || !has('popupwin') || !has('terminal')
    finish
endif
g:loaded_popup_agent = 1

# Save popup position just before it closes
augroup PopupAgent
    autocmd!
    autocmd WinClosed * popup_agent#SavePos(str2nr(expand('<awin>')))
augroup END

# :Agent [name]  — open default or named agent
command! -nargs=? -complete=customlist,popup_agent#Complete
    \ Agent popup_agent#Open(<q-args>)

# <Plug> mapping so users can rebind without touching plugin internals
nnoremap <silent> <Plug>(popup-agent-open) <Cmd>Agent<CR>

# Default <leader>a unless the user mapped <Plug>(popup-agent-open) themselves
# or set g:popup_agent_no_maps = 1
if !get(g:, 'popup_agent_no_maps', 0) && !hasmapto('<Plug>(popup-agent-open)')
    nmap <unique> <leader>a <Plug>(popup-agent-open)
endif
