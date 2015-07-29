if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_STR = type('')

function! lim#typeset#fit_str_into_width(str, width, ...) "{{{
  return s:_fit_str_into_width(a:str, a:width, get(a:, 1, 'left'), function('strwidth'))
endfunction
"}}}
function! lim#typeset#fit_str_into_width8(str, width, ...) "{{{
  return s:_fit_str_into_width(a:str, a:width, get(a:, 1, 'left'), function('strdisplaywidth'))
endfunction
"}}}
function! s:_fit_str_into_width(str, width, align, strwidthf) "{{{
  let width = a:strwidthf(a:str)
  if width > a:width
    let str = s:_trancate_to_width(a:str, a:width, a:strwidthf)
    let width = a:strwidthf(str)
  else
    let str = a:str
  end
  if width < a:width
    let padding = repeat(' ', a:width-width)
    let str = a:align=~#'r' ? padding. str : str. padding
  end
  return str
endfunction
"}}}


function! lim#typeset#trancate_to_width(str, width) "{{{
  return s:_trancate_to_width(a:str, a:width, function('strwidth'))
endfunction
"}}}
function! lim#typeset#trancate_to_width8(str, width) "{{{
  return s:_trancate_to_width(a:str, a:width, function('strdisplaywidth'))
endfunction
"}}}
function! s:_trancate_to_width(str, width, strwidthf) "{{{
  if a:width <= 0
    return ''
  end
  let twidth = a:strwidthf(a:str)
  let strarr = split(a:str, '\zs')
  let rbgnidx = len(strarr)
  let lastidx = rbgnidx-1
  let right = (rbgnidx + 1) / 2
  while twidth > a:width
    let rbgnidx = max([lastidx - right + 1, 0])
    let rwidth = a:strwidthf(join(strarr[rbgnidx : lastidx], ''))
    if twidth - rwidth >= a:width || right <= 1
      let twidth -= rwidth
      let lastidx = rbgnidx - 1
    end
    if right > 1
      let right = right / 2
    end
  endwhile
  return rbgnidx ? join(strarr[:rbgnidx-1], '') : ''
endfunction
"}}}


function! lim#typeset#keep_interval(...) "{{{
  try
    let args = s:_args(a:000, a:0)
  catch /^invalid arguments/
    throw v:exception
  endtry
  return s:_keep_interval(args, function('strwidth'))
endfunction
"}}}
function! lim#typeset#keep_interval8(...) "{{{
  try
    let args = s:_args(a:000, a:0)
  catch /^invalid arguments/
    throw v:exception
  endtry
  return s:_keep_interval(args, function('strdisplaywidth'))
endfunction
"}}}
function! s:_args(_000, len) "{{{
  let ret = {}
  let limit = a:len<3 ? a:len : 3
  let i = 0
  while i < limit
    if type(a:_000[i])==s:TYPE_LIST
      break
    end
    let i += 1
  endwhile
  if i==limit
    throw 'invalid arguments'
  end
  let ret.strlist = a:_000[i]
  if len(ret.strlist) < 2
    throw 'invalid arguments: '. string(ret.strlist)
  end
  let ret.min_lv = i > 0 ? a:_000[i-1] : 1
  let ret.base_iv = i > 1 ? a:_000[i-2] : 8
  let ret.limitwidth = get(a:_000, i+1, 0)
  let ret.over = get(a:_000, i+2, '')
  return ret
endfunction
"}}}
function! s:_keep_interval(args, strwidthf) "{{{
  let min_iv = get(a:args.strlist, 2, 2)
  if type(a:args.strlist[0])==s:TYPE_STR
    let str1 = a:args.strlist[0]
    let str1width = a:strwidthf(str1)
  else
    let str1width = a:args.strlist[0]
  end
  let lv = max([((str1width + min_iv -1) / a:args.base_iv) + 1, a:args.min_lv])
  let interval = a:args.base_iv * lv - str1width
  let str2width = a:strwidthf(a:args.strlist[1])
  if a:args.limitwidth>0 && str1width + interval + str2width > a:args.limitwidth
    let interval = a:args.limitwidth - str1width - str2width
    let interval = interval < min_iv ? min_iv : interval
    if str1width + interval + str2width > a:args.limitwidth
      if a:args.over=~#'c'
        let ret = repeat(' ', interval). a:args.strlist[1]
        let ret = s:_trancate_to_width(ret, a:args.limitwidth-str1width, a:strwidthf)
        let ret = get(l:, 'str1'. ''). repeat(' ', a:args.limitwidth-str1width - a:strwidthf(ret)). ret
      endif
    endif
  endif
  if !exists('ret')
    let ret = get(l:, 'str1', ''). repeat(' ', interval). a:args.strlist[1]
  endif
  return ret
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
