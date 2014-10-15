if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_NUM = type(0)
let s:TYPE_DICT = type({})


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
function! s:Cmdcmpl.should_optcmpl() "{{{
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
  let ordinal = get(a:, 2, 0)
  let mchs = []
  for been in self.beens
    let mchs = matchlist(been, a:pat)
    if mchs!=[]
      break
    end
  endfor
  return mchs==[] ? default : ordinal==-1 ? mchs : get(mchs, ordinal, '')
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
  let funcopts = get(a:, 1, {})
  let longbgnpat = get(funcopts, 'longbgnpat', '--')
  let shortbgnpat = get(funcopts, 'shortbgnpat', '-')
  let assignpat = get(funcopts, 'assignpat', '=')
  let endpat = '\%('.assignpat.'\(.*\)\)\?$'
  let argsrmlong = filter(copy(a:args), 'v:val !~# "^".longbgnpat')
  let ret = {}
  for [key, val] in items(a:optdict)
    let valdict = type(val)!=s:TYPE_DICT ? {'default': val} : val
    unlet val
    let pats = has_key(valdict, 'pats') ? valdict.pats : [longbgnpat. key]
    for pat in pats
      if pat!~#'^'.longbgnpat && pat=~#'^'.shortbgnpat.'.$'
        let shortchr = matchstr(pat, '^'.shortbgnpat.'\zs.$')
        let i = match(argsrmlong, '^'.shortbgnpat.'.\{-}'.shortchr.'.\{-}'.endpat)
      else
        let shortchr = ''
        let i = match(a:args, '^'.pat. endpat)
      end
      if i!=-1
        break
      end
    endfor
    if i==-1
      let ret[key] = get(valdict, 'default', 0)
      continue
    elseif shortchr==''
      let optval = substitute(remove(a:args, i), '^'.pat, '', '')
    else
      let optval = matchstr(a:args[i], shortchr. '\zs'.assignpat.'.*$')
      let a:args[i] = substitute(a:args[i], '^'.shortbgnpat.'.\{-}\zs'.shortchr. (optval=='' ? '' : assignpat.'.*'), '', '')
      if a:args[i] ==# shortbgnpat
        unlet a:args[i]
      end
    end
    let ret[key] = optval=='' ? 1 : matchstr(optval, '^'.assignpat.'\zs.*')
  endfor
  return ret
endfunction
"}}}


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
