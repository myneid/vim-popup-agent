vim9script

# Built-in agent CLI commands
const AGENTS: dict<list<string>> = {
    claude:  ['claude'],
    copilot: ['gh', 'copilot', 'chat'],
    codex:   ['codex'],
}

# Session state
var saved_line:  number = 0
var saved_col:   number = 0
var active:      dict<number> = {}   # name      -> popup_id (only while visible)
var by_id:       dict<string> = {}   # popup_id# -> name
var term_buf:    dict<number> = {}   # name      -> buf (persists while terminal runs)
var buf_to_name: dict<string> = {}   # buf#      -> name (for cleanup)


def AllAgents(): dict<list<string>>
    var result = copy(AGENTS)
    for [k, v] in items(get(g:, 'popup_agent_commands', {}))
        result[k] = v
    endfor
    return result
enddef


const CLOSE_BTN = ' [×] '

export def PopupFilter(pid: number, key: string): bool
    if key == "\<LeftMouse>"
        var mpos = getmousepos()
        var ppos = popup_getpos(pid)
        # ppos.line / ppos.col include the border; ppos.width is content-only.
        # Top border row is ppos.line; [×] occupies the last len(CLOSE_BTN)
        # columns of the title, ending one col before the right corner.
        if !empty(ppos) && mpos.screenrow == ppos.line
            \ && mpos.screencol >= ppos.col + ppos.width - len(CLOSE_BTN)
            Hide()
            return true
        endif
    endif
    return false
enddef


export def Open(arg: string)
    var name = empty(arg) ? get(g:, 'popup_agent_default', 'claude') : arg
    var agents = AllAgents()

    if !has_key(agents, name)
        echohl ErrorMsg
        echom printf('popup-agent: unknown agent "%s" — available: %s',
                     name, join(sort(keys(agents)), ', '))
        echohl None
        return
    endif

    # Re-focus an already-open popup (visible or hidden via popup_hide)
    if has_key(active, name)
        var eid = active[name]
        if index(popup_list(), eid) >= 0
            popup_show(eid)
            return
        endif
        remove(active, name)
    endif

    var w  = get(g:, 'popup_agent_width',  100)
    var h  = get(g:, 'popup_agent_height',  30)
    var ln = saved_line > 0 ? saved_line : max([1, (&lines   - h) / 2])
    var cl = saved_col  > 0 ? saved_col  : max([1, (&columns - w) / 2])

    var cmd = agents[name]
    var buf: number
    if has_key(term_buf, name) && bufexists(term_buf[name])
                \ && term_getstatus(term_buf[name]) =~# 'running'
        buf = term_buf[name]
    else
        buf = term_start(cmd, {hidden: 1, term_finish: 'close'})
        if buf <= 0
            echohl ErrorMsg
            echom printf('popup-agent: could not start "%s" (is "%s" on $PATH?)', name, cmd[0])
            echohl None
            return
        endif
        term_buf[name]    = buf
        buf_to_name[string(buf)] = name
    endif

    # Build a full-width title so [×] sits flush against the right border.
    # Vim auto-adds one separator dash on each side, so the title string itself
    # should be (content_width - 2) chars to fill the space exactly.
    var name_part = printf(' %s ', name)
    var fill_len = max([1, (w - 2) - len(name_part) - len(CLOSE_BTN)])
    var title_str = name_part .. repeat('─', fill_len) .. CLOSE_BTN

    var pid = popup_create(buf, {
        line:        ln,
        col:         cl,
        minwidth:    w,
        minheight:   h,
        maxwidth:    w,
        maxheight:   h,
        border:      [],
        borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        title:       title_str,
        drag:        1,
        resize:      1,
        close:       'none',
        mapping:     0,
        filter:      'popup_agent#PopupFilter',
    })

    active[name] = pid
    by_id[string(pid)] = name

    # In the terminal buffer, :w hides the popup instead of writing
    win_execute(pid, 'command! -buffer w call popup_agent#Hide()')
enddef


export def SavePos(win_id: number)
    var key = string(win_id)
    if !has_key(by_id, key)
        return
    endif
    var pos = popup_getpos(win_id)
    if !empty(pos)
        saved_line = pos.line
        saved_col  = pos.col
    endif
    var name = by_id[key]
    if has_key(active, name)
        remove(active, name)
    endif
    remove(by_id, key)
    # term_buf is intentionally kept — terminal process stays alive for reuse
enddef


export def OnBufDelete(buf: number)
    var key = string(buf)
    if !has_key(buf_to_name, key)
        return
    endif
    var name = buf_to_name[key]
    remove(buf_to_name, key)
    if has_key(term_buf, name) && term_buf[name] == buf
        remove(term_buf, name)
    endif
enddef


export def Hide()
    for [name, pid] in items(active)
        var pos = popup_getpos(pid)
        if !empty(pos)
            saved_line = pos.line
            saved_col  = pos.col
        endif
        popup_hide(pid)
    endfor
enddef


export def Complete(arglead: string, _cmdline: string, _pos: number): list<string>
    return sort(keys(AllAgents()))->filter((_, v) => stridx(v, arglead) == 0)
enddef
