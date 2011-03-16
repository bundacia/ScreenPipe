" Vim global plugin for sending lines to other screen windows
" Last Change: 2011 Mar 16
" Maintainer:  Trevor Little <TrevorMG19@gmail.com>
" License:     This file is placed in the public domain.

" Save current val of cpoptions and set it to it's vim default
let s:save_cpo = &cpo
set cpo&vim

" Check if loaded. Bail if it is.
if exists("loaded_srcnpipe")
    finish
endif
let loaded_srcnpipe = 1

function! s:Send () range
    " Get a List of open screens
    let screens_cmd = 'screen -ls | perl -ne "print \$1 if / \d+\. ( [^\s]+ )+ /x"'
    let screens_str = system( screens_cmd )
    let screens = split(screens_str,'\n')

    if !(exists("s:screen_session_choice") && exists("s:screen_window_choice") && input("Use previous settings? ", 'y') == 'y')
        " Build a formatted list of options
        let choices = ['Choose a screen session:']
        let index = 1
        for item in screens
            let choices = choices + [index . '. ' . item]
            let index = index + 1
        endfor

        " Let the user choose from those screen options
        let choice = inputlist( choices )
        let screen = screens[choice - 1]

        " A choice of 0 means quit
        if choice == 0
            return
        endif

        " Get a tmp file to dump the window list to
        let listfile = tempname()
        " Create a new screen named winlist. Don't attach. Background
        echo system("screen -D -m -S winlist &")
        " Create a window with a height of 60 in the new screen
        echo system("screen -S winlist -p 0 -X height 60")
        " Pull up the window list of the chosen screen session inside the new one
        echo system("screen -S winlist -p 0 -X stuff 'screen -x ".screen." -p ='")
        " Dump it to the tmpfile
        echo system("screen -S winlist -p 0 -X hardcopy " . listfile)
        " Kill the new screen session
        echo system("screen -S winlist -p 0 -X kill")
        " Get the list of windows from the screen dump
        let windows = system("awk '/^\ +[0-9]+\ / {print $1 ,\" \", $2}' " . listfile)

        " Ask the user to pick one of the windows
        echo "Found the following windows:"
        echo windows
        let window = input("Choose a window number (<Enter> cancels): ")

        " Return if not a number
        if match(window, '^\d\+$') < 0
            return
        endif

        let s:screen_session_choice = screen
        let s:screen_window_choice  = window
    endif

    " Send every line in the range to the chosen screen
    let lnum = a:firstline
    while lnum <= a:lastline
        let line = shellescape( getline(lnum) )
        echo system("screen -x " . s:screen_session_choice . " -p " .s:screen_window_choice. " -X stuff " .line. "")
        let lnum = lnum + 1
    endwhile

    echo 'Sent to screen: "' . s:screen_session_choice . '" window: "' . s:screen_window_choice .'"'

endfunction

" MAPPINGS ------------
" The idea here comes from :help write-plugin and is to setup a 
" chain of mapping that work like this:
"
"  \|  ->  <Plug>ScreenPipeSend  ->  <SID>Send  ->  :call <SID>Send()

" So first we add mapping for | to the special "<Plug>ScreenPipeSend" 
" target which is available to the user to map whatever they want to.
if !hasmapto('<Plug>ScreenPipeSend')
    map <unique> \| <Plug>ScreenPipeSend
endif
" Then map <Plug>ScreenPipeSend to our private script action <SID>Send
noremap <unique> <script> <Plug>ScreenPipeSend <SID>Send
" Then map <SID>Send to a call to our s:Send Method
noremap <SID>Send :call <SID>Send()<CR>

" Add the :ScreenPipe user command if there's no conflict
if !exists(":ScreenPipe")
    command ScreenPipe :call s:Send()
endif

" Restore cpoptions
let &cpo = s:save_cpo
