vim9script

# Built-in agent CLI commands
const AGENTS: dict<list<string>> = {
    claude:  ['claude'],
    copilot: ['copilot'],
    codex:   ['codex'],
}

# Session state
var saved_pos:   dict<list<number>> = {}  # name -> [line, col]
var active:      dict<number> = {}        # name -> popup_id (only while visible)
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
    # popup_hide is forbidden for terminal popups (E863); close the popup
    # instead — the terminal buffer persists in term_buf while the job runs.
    # WinClosed fires and SavePos cleans up active/by_id.
    popup_close(pid)
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

    # If the popup is currently open and visible, nothing to do.
    if has_key(active, name)
        var eid = active[name]
        if !empty(popup_getpos(eid))
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

    var pid = popup_create(buf, {
        line:        ln,
        col:         cl,
        minwidth:    w,
        minheight:   h,
        maxwidth:    w,
        maxheight:   h,
        border:      [],
        borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        title:       printf(' %s ', name),
        drag:        1,
        resize:      1,
        close:       'button',
        mapping:     0,
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
