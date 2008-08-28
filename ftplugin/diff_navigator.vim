" ============================================================================
" File:         diff_navigator.vim
" Description:  Filetype plugin to ease navigation in (unified) diffs
" Maintainer:   Petr Uzel <petr.uzel -at- centrum.cz>
" Version:      0.1
" Last Change:  27 Aug, 2008
" License:      This program is free software. It comes without any warranty,
"               to the extent permitted by applicable law. You can redistribute
"               it and/or modify it under the terms of the Do What The Fuck You
"               Want To Public License, Version 2, as published by Sam Hocevar.
"               See http://sam.zoy.org/wtfpl/COPYING for more details.
"
" Bugs:         Send bugreports/patches directly to me via mail
" Dependencies: filterdiff (part of patchutils project)
"
"
" TODO:         show current hunk in status line
" TODO:         delete hunk/whole file diff - like http://www.vim.org/scripts/script.php?script_id=444)
" TODO:         incorporate more patchutils functionality
" TODO:         something like taglist for diff (shows all files/hunks in the diff)
" TODO:         option for *Next|Prev* funtions to wrap around end of file
" ============================================================================


" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

" Annotate each hunk with it's number and name of the changed file
if !exists("*s:DiffAnnotate")
    function s:DiffAnnotate()
       if !executable('filterdiff') 
           echohl WarningMsg
           echo "You need to install filterdiff first (part of patchutils)"
           echohl None
           return
       endif
       let l:cursorpos = winsaveview()
       %!filterdiff --annotate
       call winrestview(cursorpos) 
    endfunction
endif

" Print annotation of current hunk
if !exists("*s:DiffShowHunk")
    function s:DiffShowHunk()
       " if the current line begins with '+++' or '---', then it makes sense to search
       " forwards
       if getline(".") =~ '^+++ \|^--- '
           let l:lineno = search('^@@[ +-\,\d]*@@.*$', 'ncW')
       else
           let l:lineno = search('^@@[ +-\,\d]*@@.*$', 'bncW')
       endif
       if l:lineno == 0
           return
       endif
       let l:hunk_annotation = substitute(getline(lineno), '^@@[ +-\,\d]*@@\s*\(.*\)$', '\1', '')
       echo l:hunk_annotation
    endfunction
endif

" Skip to next hunk
if !exists("*s:DiffNextHunk")
    function s:DiffNextHunk()
       call search('^@@[ +-\,\d]*@@', 'sW')
    endfunction
endif

" Skip to previous hunk
if !exists("*s:DiffPrevHunk")
    function s:DiffPrevHunk()
       call search('^@@[ +-\,\d]*@@', 'bsW')
    endfunction
endif

" Skip to next changed file
if !exists("*s:DiffNextFile")
    function s:DiffNextFile()
        call search('^--- ', 'sW')
    endfunction
endif

" Skip to previous changed file 
if !exists("*s:DiffPrevFile")
    function s:DiffPrevFile()
        call search('^--- ', 'bsW')
    endfunction
endif

command! -buffer DiffAnnotate call s:DiffAnnotate()
command! -buffer DiffShowHunk call s:DiffShowHunk()
command! -buffer DiffNextHunk call s:DiffNextHunk()
command! -buffer DiffPrevHunk call s:DiffPrevHunk()
command! -buffer DiffNextFile call s:DiffNextFile()
command! -buffer DiffPrevFile call s:DiffPrevFile()


" Default },{,(,) do not make much sense in diffs, so remap them to
" make something useful
nnoremap <buffer> } :DiffNextFile<CR>
nnoremap <buffer> { :DiffPrevFile<CR>
nnoremap <buffer> ) :DiffNextHunk<CR>
nnoremap <buffer> ( :DiffPrevHunk<CR>

