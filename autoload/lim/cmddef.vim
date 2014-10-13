if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_NUM = type(0)
"Misc:
function! s:_parse_option(arg, optionpat, optdict, suppresserr) "{{{
  let [opt, val] = matchlist(a:arg, a:optionpat)[1:2]
  if has_key(a:optdict, opt)
    let a:optdict[opt] = type(a:optdict[opt])==s:TYPE_NUM && val=='' ? 1 : val
    return
  end
  if !a:suppresserr
    echoerr "unknown option `". opt. "'"
  end
endfunction
"}}}
function! s:_parse_switch(arg, switchpat, switchdict, suppresserr) "{{{
  let [swts, val] = matchlist(a:arg, a:switchpat)[1:2]
  if val==''
    for switch in split(swts, '\zs')
      if has_key(a:switchdict, switch)
        let a:switchdict[switch] = 1
        continue
      end
      if !a:suppresserr
        echoerr "unknown switch `". switch. "'"
      end
    endfor
  else
    if has_key(a:switchdict, swts)
      let a:switchdict[swts] = val
      return
    end
    if !a:suppresserr
      echoerr "unknown switch `". swts. "'"
    end
  end
endfunction
"}}}


"=============================================================================
"Main:
let s:Cmdcmpl = {}
function! lim#cmddef#newCmdcmpl(cmdline, cursorpos, ...) abort "{{{
  let obj = copy(s:Cmdcmpl)
  let obj.funcopts = get(a:, 1, {})
  let obj.cmdline = a:cmdline
  let obj.cursorpos = a:cursorpos
  let obj.is_on_edge = a:cmdline[a:cursorpos-1]!=' ' ? 0 : a:cmdline[a:cursorpos-2]!='/' || a:cmdline[a:cursorpos-3]=='/'
  let obj.beens = split(a:cmdline, '\%(\\\@<!\s\)\+')[1:]
  let obj.words_til_crs = split(a:cmdline[:(a:cursorpos-1)], '\%(\\\@<!\s\)\+')
  let obj.arglead = obj.is_on_edge ? '' : obj.words_til_crs[-1]
  let obj.save_ordinals = {}
  return obj
endfunction
"}}}
function! s:Cmdcmpl.get_ordinal(...) "{{{
  let NULL = "\<C-n>"
  let ignorepat = a:0 ? a:1 : get(self.funcopts, 'optpat', '')
  let ignorepat = ignorepat=='' ? NULL : ignorepat
  if has_key(self.save_ordinals, ignorepat)
    return self.save_ordinals[ignorepat]
  end
  let transient = copy(self.words_til_crs)
  if ignorepat != NULL
    call filter(transient, 'v:val !~# ignorepat')
  end
  let ret = len(transient)-1
  let self.save_ordinals[ignorepat] = self.is_on_edge ? ret+1 : ret
  return self.save_ordinals[ignorepat]
endfunction
"}}}
function! s:Cmdcmpl.should_complete_options() "{{{
  let pat = get(self.funcopts, 'optpat', '')
  return pat!='' && self.arglead =~# pat
endfunction
"}}}
function! s:Cmdcmpl.is_matched(pat) "{{{
  return self.arglead =~# a:pat
endfunction
"}}}
function! s:Cmdcmpl.get_arg(pat, ...) "{{{
  let default = get(a:, 1, '')
  let ordinal = get(a:, 2, -1)
  let mchs = []
  for been in self.beens
    let mchs = matchlist(been, a:pat)
    if mchs!=[]
      break
    end
  endfor
  return mchs==[] ? default : !ordinal ? mchs : ordinal==-1 ? mchs[0] : get(mchs, ordinal, '')
endfunction
"}}}
function! s:Cmdcmpl.mill_candidates(candidates, ...) "{{{
  let funcopts = get(a:, 1, {})
  let conflicts = has_key(funcopts, 'conflicts') ? funcopts.conflicts : get(self.funcopts, 'conflicts', [])
  let reuses = get(funcopts, 'reuses', [])
  let reuses = type(reuses)!=s:TYPE_NUM ? reuses : reuses ? a:candidates : []
  call self._solve_conflicts(a:candidates, conflicts)
  let beens = filter(copy(self.beens), 'index(reuses, v:val)==-1')
  return filter(a:candidates, 'v:val =~ "^".self.arglead && index(beens, v:val)==-1')
endfunction
"}}}

function! s:Cmdcmpl._solve_conflicts(candidates, conflicts) "{{{
  for confs in a:conflicts
    for conf in confs
      if index(self.beens, conf)!=-1
        call filter(a:candidates, 'index(confs, v:val)==-1')
        break
      end
    endfor
  endfor
endfunction
"}}}


"--------------------------------------
function! lim#cmddef#parse_options(args, optdict, ...) "{{{
  let switchdict = get(a:, 1, {})
  let addinfo = get(a:, 2, {})
  let optionpat = get(addinfo, 'optionpat', '\m^--\([[:alnum:]-]\+\)\%(=\(.*\)\)\?')
  let switchpat = get(addinfo, 'switchpat', '\m^-\([[:alnum:]]\+\)\%(=\(.*\)\)\?')
  let suppresserr = get(addinfo, 'suppresserr', 0)
  let i = len(a:args)
  while i
    let i -= 1
    let arg = a:args[i]
    if arg =~ optionpat
      call s:_parse_option(arg, optionpat, a:optdict, suppresserr)
      unlet a:args[i]
    elseif arg =~ switchpat
      call s:_parse_switch(arg, switchpat, switchdict, suppresserr)
      unlet a:args[i]
    end
  endwhile
  return [a:optdict, switchdict]
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
