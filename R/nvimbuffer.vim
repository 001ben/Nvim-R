" This file contains code used only when R run in Neovim buffer

function ExeOnRTerm(cmd)
    let curbuf = bufname("%")
    let savesb = &switchbuf
    set switchbuf=useopen
    exe 'sb ' . g:rplugin_R_bufname
    exe a:cmd
    call cursor("$", 1)
    exe 'sb ' . curbuf
    exe 'set switchbuf=' . savesb
endfunction

function SendCmdToR_Neovim(...)
    if g:rplugin_R_job
        if g:R_ca_ck
            let cmd = "\001" . "\013" . a:1
        else
            let cmd = a:1
        endif

        if !exists("g:R_hl_term") || !exists("g:R_setwidth")
            call SendToNvimcom("\x08" . $NVIMR_ID . 'paste(search(), collapse=" ")')
            let g:rplugin_lastev = ReadEvalReply()
            if !exists("g:R_hl_term")
                if g:rplugin_lastev =~ "colorout"
                    let g:R_hl_term = 0
                else
                    let g:R_hl_term = 1
                endif
            endif
            if !exists("g:R_setwidth")
                if g:rplugin_lastev =~ "setwidth"
                    let g:R_setwidth = 0
                else
                    let g:R_setwidth = 1
                endif
            endif
        endif

        if !exists("g:rplugin_hl_term")
            let g:rplugin_hl_term = g:R_hl_term
            if g:rplugin_hl_term
                call ExeOnRTerm('set filetype=rout')
            endif
        endif

        " Update the width, if necessary
        if g:R_setwidth && len(filter(tabpagebuflist(), "v:val =~ bufnr(g:rplugin_R_bufname)")) >= 1
            call ExeOnRTerm("let s:rwnwdth = winwidth(0)")
            if s:rwnwdth != g:rplugin_R_width && s:rwnwdth != -1 && s:rwnwdth > 10 && s:rwnwdth < 999
                let g:rplugin_R_width = s:rwnwdth
                call SendToNvimcom("\x08" . $NVIMR_ID . "options(width=" . g:rplugin_R_width. ")")
                sleep 10m
            endif
        endif

        if a:0 == 2 && a:2 == 0
            call jobsend(g:rplugin_R_job, cmd)
        else
            call jobsend(g:rplugin_R_job, cmd . "\n")
        endif
        return 1
    else
        call RWarningMsg("Is R running?")
        return 0
    endif
endfunction

function StartR_Neovim()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        " We could run 'call RQuit("restartR")' instead of returning if it was
        " possible to close the terminal buffer automatically. This would make
        " R_restart work with R_in_buffer too.
        return
    endif
    let g:R_tmux_split = 0

    let g:SendCmdToR = function('SendCmdToR_Neovim')

    let edbuf = bufname("%")
    let objbrttl = b:objbrtitle
    let curbufnm = bufname("%")
    set switchbuf=useopen
    if g:R_vsplit
        if g:R_rconsole_width > 16 && g:R_rconsole_width < (winwidth(0) - 16)
            silent exe "belowright " . g:R_rconsole_width . "vnew"
        else
            silent belowright vnew
        endif
    else
        if g:R_rconsole_height > 6 && g:R_rconsole_height < (winheight(0) - 6)
            silent exe "belowright " . g:R_rconsole_height . "new"
        else
            silent belowright new
        endif
    endif
    let g:rplugin_R_job = termopen(g:rplugin_R . " " . join(g:rplugin_r_args), {'on_exit': function('ROnJobExit')})
    let g:rplugin_R_bufname = bufname("%")
    let g:rplugin_R_width = 0
    let b:objbrtitle = objbrttl
    let b:rscript_buffer = curbufnm
    if exists("g:R_hl_term") && g:R_hl_term
        set filetype=rout
        let g:rplugin_hl_term = g:R_hl_term
    endif
    if g:R_esc_term
        tnoremap <buffer> <Esc> <C-\><C-n>
    endif
    exe "sbuffer " . edbuf
    stopinsert
    call WaitNvimcomStart()
endfunction

if has("win32")
    " The R package colorout only works on Unix systems
    call RSetDefaultValue("g:R_hl_term", 1)
endif
