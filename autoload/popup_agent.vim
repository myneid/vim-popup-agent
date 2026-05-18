vim9script

# Built-in agent CLI commands
const AGENTS: dict<list<string>> = {
    claude:  ['claude'],
    copilot: ['gh', 'copilot', 'chat'],
    codex:   ['codex'],
}

# Session state
var saved_line: number = 0
var saved_col:  number = 0
var active:     dict<number> = {}   # name       -> popup_id
var by_id:      dict<string> = {}   # popup_id# -> name


def AllAgents(): dict<list<string>>
    var result = copy(AGENTS)
    for [k, v] in items(get(g:, 'popup_agent_commands', {}))
        result[k] = v
    endfor
    return result
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

    # Re-focus an already-visible popup
    if has_key(active, name)
        var eid = active[name]
        if !empty(popup_getpos(eid))
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
    var buf = term_start(cmd, {hidden: 1, term_finish: 'close'})
    if buf <= 0
        echohl ErrorMsg
        echom printf('popup-agent: could not start "%s" (is "%s" on $PATH?)', name, cmd[0])
        echohl None
        return
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
        title:       printf('  %s  ', name),
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
enddef


export def Complete(arglead: string, _cmdline: string, _pos: number): list<string>
    return sort(keys(AllAgents()))->filter((_, v) => stridx(v, arglead) == 0)
enddef
