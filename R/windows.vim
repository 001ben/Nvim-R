" This file contains code used only on Windows

let g:rplugin_sumatra_path = ""
let g:rplugin_python_initialized = 0

call RSetDefaultValue("g:R_sleeptime", 100)
call RSetDefaultValue("g:R_i386", 0)

" Avoid invalid values defined by the user
exe "let s:sleeptimestr = " . '"' . g:R_sleeptime . '"'
let s:sleeptime = str2nr(s:sleeptimestr)
if s:sleeptime < 1 || s:sleeptime > 1000
    let g:R_sleeptime = 100
endif
unlet s:sleeptimestr
unlet s:sleeptime

let g:rplugin_sleeptime = g:R_sleeptime . 'm'

if !exists("g:rplugin_R_path")
    call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s'], g:rplugin_tmpdir . "/run_reg.bat")
    let rip = filter(split(system(g:rplugin_tmpdir . "/run_reg.bat"), "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    let g:rdebug_reg_rpath_1 = rip
    if len(rip) > 0
        let s:rinstallpath = substitute(rip[0], '.*InstallPath.*REG_SZ\s*', '', '')
        let s:rinstallpath = substitute(s:rinstallpath, '\n', '', 'g')
        let s:rinstallpath = substitute(s:rinstallpath, '\s*$', '', 'g')
        let g:rdebug_reg_rpath_2 = s:rinstallpath
    endif
    if !exists("s:rinstallpath")
        call RWarningMsgInp("Could not find R path in Windows Registry. If you have already installed R, please, set the value of 'R_path'.")
        let g:rplugin_failed = 1
        finish
    endif
    if isdirectory(s:rinstallpath . '\bin\i386')
        if !isdirectory(s:rinstallpath . '\bin\x64')
            let g:R_i386 = 1
        endif
        if g:R_i386
            let $PATH = s:rinstallpath . '\bin\i386;' . $PATH
        else
            let $PATH = s:rinstallpath . '\bin\x64;' . $PATH
        endif
    else
        let $PATH = s:rinstallpath . '\bin;' . $PATH
    endif
    unlet s:rinstallpath
endif

if !exists("g:R_args")
    let g:R_args = ["--sdi"]
endif

let g:R_R_window_title = "R Console"

function FindSumatra()
    if executable($ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe")
        let g:rplugin_sumatra_path = $ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe"
        return 1
    endif
    call writefile(['reg.exe QUERY "HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths" /v "SumatraPDF.exe"'], g:rplugin_tmpdir . "/run_reg.bat")
    let smtr = system(g:rplugin_tmpdir . "/run_reg.bat")
    if len(smtr) > 0
        let g:rdebug_reg_personal = smtr
        let smtr = substitute(smtr, '.*REG_SZ\s*', '', '')
        let smtr = substitute(smtr, '\n', '', 'g')
        let smtr = substitute(smtr, '\s*$', '', 'g')
        if executable(smtr)
            let g:rplugin_sumatra_path = smtr
            return 1
        else
            call RWarningMsg('Sumatra not found: "' . smtr . '"')
        endif
    else
        call RWarningMsg("SumatraPDF not found in Windows registry.")
    endif
    return 0
endfunction

function StartR_Windows()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        call RWarningMsg('R was already started.')
    endif

    " R and Vim use different values for the $HOME variable.
    let saved_home = $HOME
    call writefile(['reg.exe QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal"'], g:rplugin_tmpdir . "/run_reg.bat")
    let prs = system(g:rplugin_tmpdir . "/run_reg.bat")
    if len(prs) > 0
        let g:rdebug_reg_personal = prs
        let prs = substitute(prs, '.*REG_SZ\s*', '', '')
        let prs = substitute(prs, '\n', '', 'g')
        let prs = substitute(prs, '\r', '', 'g')
        let prs = substitute(prs, '\s*$', '', 'g')
        let g:rdebug_reg_personal2 = prs
        let $HOME = prs
    endif

    let g:rplugin_R_job = jobstart(g:rplugin_R . ' ' . join(g:R_args))

    let $HOME = saved_home

    let g:SendCmdToR = function('SendCmdToR_Windows')
    if WaitNvimcomStart()
        if g:R_arrange_windows && filereadable(g:rplugin_compldir . "/win_pos")
            " ArrangeWindows
            call jobsend(g:rplugin_clt_job, "\005" . g:rplugin_compldir . "\n")
        endif
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    endif
endfunction

function SendCmdToR_Windows(...)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:1 . "\n"
    else
        let cmd = a:1 . "\n"
    endif
    " FIXME: save and restore clipboard contents
    "let save_clip = getreg('+')
    "call setreg('+', cmd)

    " SendToRConsole
    call jobsend(g:rplugin_clt_job, "\003" . cmd)

    " Raise Neovim window
    exe "sleep " . g:rplugin_sleeptime
    call jobsend(g:rplugin_clt_job, "\007 \n")

    "call setreg('+', save_clip)
    return 1
endfunction

