" ============================================================================
" File:         diff_navigator.vim
" Description:  Filetype plugin to ease navigation in (unified) diffs
" Maintainer:   Petr Uzel <petr.uzel -at- centrum.cz>,
"               Matěj Cepl <mcepl -at- cepl dot eu>
" Version:      0.2
" Last Change:  10 Sep, 2013
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
" TODO:         delete whole file diff -
"               like http://www.vim.org/scripts/script.php?script_id=444)
" TODO:         incorporate more patchutils functionality
" TODO:         something like taglist for diff (shows all files/hunks in
"               the diff)
" TODO:         option for *Next|Prev* funtions to wrap around end of file
" ============================================================================


" Only do this when not done yet for this buffer
" Usually, not needed, just for the keeping normal API
if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

" Load this plugin only once
if exists("g:loaded_diff_navigator")
    finish
endif
let g:loaded_diff_navigator = 1

function s:checkFilterDiff()
    if !executable('filterdiff')
        echohl WarningMsg
        echo "You need to install filterdiff first (part of patchutils)"
        echohl None
        return 0
    endif
    return 1
endfunction

" Given the linenumber of the hunk returned its parsed content
"
" From http://www.clearchain.com/blog/posts/splitting-a-patch
" -----------------------------------------------------------
"
" here’s at least some info about the format of a patch file.
"
" @@ -143,6 +143,13 @@
"
"     the first number is the starting line for this hunk in oldfile
"     the second number is the number of original source lines in this
"         hunk (this includes lines marked with “-”)
"     the third number is the starting line for this hunk in newfile
"     the last number is the number of lines after the hunk has been applied.
function s:parseHunkHeader(lineno)
    let inline = getline(a:lineno)
    " Thanks to somian from #vim IRC channel for this incredible RE
    let hunk_nos = substitute(inline,
         \ '\_^\S\S\s\+-\(\d\+\),\(\d\+\)\s\++\(\d\+\),\(\d\+\)\s\+\S\S\(\_.*\)',
         \ "\\1,\\2,\\3,\\4,\\5","")
    let result = split(hunk_nos, ",")

    return {
        \ 'line': a:lineno,
        \ 'oldFirst': result[0],
        \ 'oldCount': result[1],
        \ 'newFirst': result[2],
        \ 'newCount': result[3],
        \ 'remainderLine': join(result[4:], ",")
        \ }
endfunction

" Get hunk header from the hunk surrounding cursor
function s:getCurrentHunkHeader()
    if getline(".") =~ '^+++ \|^--- '
        let lineno = search('^@@[ +-\,\d]*@@.*$', 'ncW')
    else
        let lineno = search('^@@[ +-\,\d]*@@.*$', 'bncW')
    endif

    return s:parseHunkHeader(lineno)
endfunction

" Generate hunk header line
function s:createHunkHeader(oldStart, oldLen, newStart, newLen, remaind)
    return "@@ -" . a:oldStart . "," . a:oldLen .
        \ " +" . a:newStart . "," . a:newLen . " @@" . a:remaind
endfunction

" Return number of lines in the range between start and end line (both
" inclusive) which are from the state before patch and the one after
" patch is applied.
function s:countLines(start, end)
    let context_lines = 0
    let old_lines = 0
    let new_lines = 0

    for line in getline(a:start, a:end)
        let first_char = strpart(line, 0, 1)
        if first_char == ' '
            let context_lines = context_lines + 1
        elseif first_char == '-'
            let old_lines = old_lines + 1
        elseif first_char == '+'
            let new_lines = new_lines + 1
        else
        endif
    endfor

    return [context_lines + old_lines, context_lines + new_lines]
endfunction

" -------------------------------------------------------------

" Annotate each hunk with it's number and name of the changed file
function s:DiffAnnotate()
    if s:checkFilterDiff()
        let l:cursorpos = winsaveview()
        %!filterdiff --annotate
        call winrestview(cursorpos)
    endif
endfunction

" Print annotation of current hunk
function s:DiffShowHunk()
    " if the current line begins with '+++' or '---', then it makes
    " sense to search forwards
    let hunk_header = s:getCurrentHunkHeader()
    let l:hunk_annotation = substitute(getline(hunk_header['line']),
        \ '^@@[ +-\,\d]*@@\s*\(.*\)$', '\1', '')
    echo l:hunk_annotation
endfunction

" Skip to next hunk
function s:DiffNextHunk()
    call search('^@@[ +-\,\d]*@@', 'sW')
endfunction

" Skip to previous hunk
function s:DiffPrevHunk()
    call search('^@@[ +-\,\d]*@@', 'bsW')
endfunction

" Skip to next changed file
function s:DiffNextFile()
    call search('^--- ', 'sW')
endfunction

" Skip to previous changed file
function s:DiffPrevFile()
    call search('^--- ', 'bsW')
endfunction

function s:DiffSplitHunk()
    let old_cur_header = s:getCurrentHunkHeader()
    let cur_line_no = line(".")

    " With this hunk:
    "
    " @@ -20,8 +20,17 @@ Hunk #1, a/tests/test_ec_curves.py
    "
    "  import unittest
    "  #import sha
    " -from M2Crypto import EC, Rand
    " -from test_ecdsa import ECDSATestCase as ECDSATest
    " +try:
    " +    from M2Crypto import EC, Rand
"-- " +    from test_ecdsa import ECDSATestCase as ECDSATest
    " +# AttributeError: 'module' object has no attribute 'ec_init'
    " +#except AttributeError:
    " +except:
    " +    EC_Module_Available = False
    " +    print("No EC modules available")
    " +else:
    " +    EC_Module_Available = True
    " +    print("EC modules are available")
    "
    " creates above the line
    " @@ -25,3 +25,12 @@
    "
    " and the original hunk line is now
    " @@ -20,5 +20,5 @@ Hunk #1, a/tests/test_ec_curves.py
    "
    "
    " Start line below header and stop one line above the current line
    let diff_lines = s:countLines(old_cur_header['line'] + 1,
        \ cur_line_no - 1)
    let diff_old = diff_lines[0]
    let diff_new = diff_lines[1]

    " IN THE NEW START HUNK HEADER
    " 1. length is number of lines above the current position which
    " are either context or deleted lines (-)
    " 2. length is number of lines above the current position which
    " are either context or added lines (+)
    " Start positions are same as well the stuff after the second @@
    let new_start_del_start = old_cur_header['oldFirst']
    let new_start_del_len = diff_old
    let new_start_add_start = old_cur_header['newFirst']
    let new_start_add_len = diff_new
    let @x = s:createHunkHeader(new_start_del_start, new_start_del_len,
        \ new_start_add_start, new_start_add_len,
        \ old_cur_header['remainderLine'])
    let window_state = winsaveview()
    " write the new original header line
    call setpos(".", [0, old_cur_header['line'], 1, 0])
    normal ^d$"xp
    call winrestview(window_state)

    " IN THE NEW HUNK HEADER
    " new lengths = original len - new len
    " new starts = original start + (difference)
    let new_pos_del_start = old_cur_header['oldFirst'] + diff_old
    let new_pos_del_len = old_cur_header['oldCount'] - diff_old
    let new_pos_add_start = old_cur_header['newFirst'] + diff_new
    let new_pos_add_len = old_cur_header['newCount'] - diff_new
    let @x = s:createHunkHeader(new_pos_del_start, new_pos_del_len,
        \ new_pos_add_start, new_pos_add_len, "")
    execute "normal! O\<Esc>\"xP"
endfunction

" Delete the hunk cursor is in.
function s:DiffDeleteHunk()
    let last_hunk_in_file = 0

    let start_hunk_line = search('^@@[ +-\,\d]*@@.*$', 'bncW')
    " we are before the first hunk ... return
    if start_hunk_line == 0
        return
    endif

    " end of the hunk is start of next hunk or next file, whichever
    " comes first
    let next_hunk_line = search('^@@[ +-\,\d]*@@.*$', 'nW')
    let start_of_next_file_line = search('^--- .*$', 'ncW')
    if start_of_next_file_line > 0 &&
            \ start_of_next_file_line < next_hunk_line
        let next_hunk_line = start_of_next_file_line
        let last_hunk_in_file = 1
    endif

    " if this is the last hunk in the file ... just erase everything
    " from the start of the hunk (inclusive) to the end
    if next_hunk_line == 0
        execute start_hunk_line . ",$" . "d"
    " we are in the middle of the file ... it's a bit more complicated
    else
        let count_lines = s:countLines(start_hunk_line + 1,
            \ next_hunk_line - 1)
        let added_lines = count_lines[1] - count_lines[0]
        call setpos(".", [0, next_hunk_line, 1, 0])
        execute start_hunk_line . "," . (next_hunk_line - 1) . "d"

        " record the line number of the new hunk header after delete
        let new_header_line = line(".")

        " recalculate current hunk header
        while ! last_hunk_in_file
            let cur_header = s:parseHunkHeader(line("."))
            let old_line = cur_header['newFirst']
            let new_line = old_line - added_lines
            let @x = substitute(getline("."), "+" . old_line . ",",
                \ "+" . new_line . ",", "")
            normal ^d$"xp

            " check the next hunk
            let next_hunk_line = search('\_^@@[ +-\,\d]*@@\_.*\_$', 'nW')
            let start_of_next_file_line = search('^--- .*$', 'ncW')
            if start_of_next_file_line < next_hunk_line
                let next_hunk_line = start_of_next_file_line
                let last_hunk_in_file = 1
            endif
            call setpos(".", [0, next_hunk_line, 1, 0])
        endwhile

        " jump to the line after the deleted hunk
        call setpos(".", [0, new_header_line, 1, 0])
    endif
endfunction

" Define new commands
command DiffAnnotate    call s:DiffAnnotate()
command DiffShowHunk    call s:DiffShowHunk()
command DiffNextHunk    call s:DiffNextHunk()
command DiffPrevHunk    call s:DiffPrevHunk()
command DiffNextFile    call s:DiffNextFile()
command DiffPrevFile    call s:DiffPrevFile()
command DiffSplitHunk   call s:DiffSplitHunk()
command DiffDeleteHunk  call s:DiffDeleteHunk()


" Default },{,(,) do not make much sense in diffs, so remap them to
" make something useful
nnoremap <silent> <script> } :call <SID>DiffNextFile()<CR>
nnoremap <silent> <script> { :call <SID>DiffPrevFile()<CR>
nnoremap <silent> <script> ) :call <SID>DiffNextHunk()<CR>
nnoremap <silent> <script> ( :call <SID>DiffPrevHunk()<CR>
nnoremap <silent> <script> ! :call <SID>DiffShowHunk()<CR>
nnoremap <silent> <script> <leader>s :call <SID>DiffSplitHunk()<CR>
nnoremap <silent> <script> <leader>d :call <SID>DiffDeleteHunk()<CR>
