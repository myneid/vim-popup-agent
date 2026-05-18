vim9script

# Built-in agent CLI commands
const AGENTS: dict<list<string>> = {
    claude:  ['claude'],
    copilot: ['gh', 'copilot', 'chat'],
    codex:   ['codex'],
}

# Session state
var saved_pos:   dict<list<number>> = {}  # name -> [line, col]
var active:      dict<number> = {}        # name -> popup_id (visible or hidden)
var by_id:       dict<string> = {}        # popup_id# -> name
var term_buf:    dict<number> = {}        # name -> buf (persists while terminal runs)
var buf_to_name: dict<string> = {}        # buf# -> name (for cleanup)


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
        # ppos.line is the top border row; ppos.col is the left border column.
        # ppos.width is content width (excludes borders).
        # Title fills the full content width so CLOSE_BTN sits in the last
        # strwidth(CLOSE_BTN) columns before the right border corner.
        if !empty(ppos) && mpos.screenrow == ppos.line
            \ && mpos.screencol >= ppos.col + ppos.width - strwidth(CLOSE_BTN)
            HideOne(pid)
            return true
        endif
    endif
    return false
enddef


def HideOne(pid: number)
    var key = string(pid)
    if !has_key(by_id, key)
        return
    endif
    var name = by_id[key]
    var pos = popup_getpos(pid)
    if !empty(pos)
        saved_pos[name] = [pos.line, pos.col]
    endif
    # popup_hide preserves the terminal job; popup_close would kill it.
    popup_hide(pid)
    # Keep active/by_id intact — the popup still exists, just not visible.
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

    # Re-show an already-tracked popup (visible or hidden via popup_hide).
    if has_key(active, name)
        var eid = active[name]
        if !empty(popup_getpos(eid))
            popup_show(eid)
            return
        endif
        # Stale entry — popup was closed without going through SavePos.
        remove(active, name)
        remove(by_id, string(eid))
    endif

    var w  = get(g:, 'popup_agent_width',  100)
    var h  = get(g:, 'popup_agent_height',  30)
    var pos = get(saved_pos, name, [])
    var ln = empty(pos) ? max([1, (&lines   - h) / 2]) : pos[0]
    var cl = empty(pos) ? max([1, (&columns - w) / 2]) : pos[1]

    var cmd = agents[name]
    var buf: number
    if has_key(term_buf, name) && bufexists(term_buf[name])
                \ && term_getstatus(term_buf[name]) =~# 'running'
        buf = term_buf[name]
    else
        buf = term_start(cmd, {hidden: 1, term_finish: 'close', term_name: name})
        if buf <= 0
            echohl ErrorMsg
            echom printf('popup-agent: could not start "%s" (is "%s" on $PATH?)', name, cmd[0])
            echohl None
            return
        endif
        term_buf[name]        = buf
        buf_to_name[string(buf)] = name
    endif

    # Title fills the full content width (w columns) so [×] sits flush
    # against the right border corner. Use strwidth() for multibyte safety.
    var name_part = printf(' %s ', name)
    var fill_len = max([1, w - strwidth(name_part) - strwidth(CLOSE_BTN)])
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
enddef


export def SavePos(win_id: number)
    var key = string(win_id)
    if !has_key(by_id, key)
        return
    endif
    var name = by_id[key]
    var pos = popup_getpos(win_id)
    if !empty(pos)
        saved_pos[name] = [pos.line, pos.col]
    endif
    remove(active, name)
    remove(by_id, key)
    # term_buf is intentionally kept — terminal process stays alive for reuse.
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
    for [name, pid] in items(copy(active))
        HideOne(pid)
    endfor
enddef


export def Complete(arglead: string, _cmdline: string, _pos: number): list<string>
    return sort(keys(AllAgents()))->filter((_, v) => stridx(v, arglead) == 0)
enddef
