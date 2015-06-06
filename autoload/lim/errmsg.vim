if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! lim#errmsg#echom_exception(msg, ...) "{{{
  try
    if a:0
      call s:_showthrowpoint('echom', a:msg)
      call s:_showexception('echom', a:1)
    else
      call s:_showexception('echom', a:msg)
    end
  finally
    echoh NONE
  endtry
endfunction
"}}}
function! lim#errmsg#echo_exception(msg, ...) "{{{
  try
    if a:0
      call s:_showthrowpoint('echo', a:msg)
      call s:_showexception('echo', a:1)
    else
      call s:_showexception('echo', a:msg)
    end
  finally
    echoh NONE
  endtry
endfunction
"}}}

function! s:_showthrowpoint(echocmd, premsg) "{{{
  echoh ErrorMsg
  let tp = matchlist(v:throwpoint, '^\(.\+\), \(\S\+ \d\+\)$')
  exe a:echocmd string((a:premsg=='' ? 'Error detected while processing ' : a:premsg. ' '). tp[1]. ':')
  echoh LineNr
  exe a:echocmd string(substitute(tp[2], '\s', '    ', ''). ':')
  echoh ErrorMsg
endfunction
"}}}
function! s:_showexception(echocmd, premsg) "{{{
  echoh ErrorMsg
  exe a:echocmd string((a:premsg=='' ? '' : a:premsg.' '). substitute(v:exception, '^Vim\%((\S\+)\)\?:', '', ''))
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
