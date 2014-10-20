if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})

"Misc:
function! s:_match_arg(pat, variadic, list) "{{{
  if type(a:pat)==s:TYPE_LIST
    let [idx, default] = [get(a:variadic, 0, 0), get(a:variadic, 1, '')]
    return get(filter(copy(a:list), 'index(a:pat, v:val)!=-1'), idx, default)
  end
  let default = get(a:variadic, 0, '')
  let idx = match(a:list, a:pat)
  return idx==-1 ? default : a:list[i]
endfunction
"}}}
function! s:_match_args(pat, list) "{{{
  if type(a:pat)==s:TYPE_LIST
    return filter(a:list, 'index(a:pat, v:val)!=-1')
  end
  return filter(a:list, 'v:val =~ a:pat')
endfunction
"}}}


"=============================================================================
"Main:
let s:Cmdcmpl = {}
function! lim#cmddef#newCmdcmpl(cmdline, cursorpos, ...) abort "{{{
  let obj = copy(s:Cmdcmpl)
  let obj.funcopts = get(a:, 1, {})
  let obj.funcopts.optbgnpat = get(obj.funcopts, 'optbgnpat', '^--\?')
  let obj.cmdline = a:cmdline
  let obj.cursorpos = a:cursorpos
  let obj.is_on_edge = a:cmdline[a:cursorpos-1]!=' ' ? 0 : a:cmdline[a:cursorpos-2]!='/' || a:cmdline[a:cursorpos-3]=='/'
  let obj.beens = split(a:cmdline, '\%(\\\@<!\s\)\+')[1:]
  let obj.leftwords = split(a:cmdline[:(a:cursorpos-1)], '\%(\\\@<!\s\)\+')
  let obj.arglead = obj.is_on_edge ? '' : obj.leftwords[-1]
  let obj.preword = obj.is_on_edge ? obj.leftwords[-1] : obj.leftwords[-2]
  let obj.save_settlednums = {}
  return obj
endfunction
"}}}
function! s:Cmdcmpl.get_arglead() "{{{
  return self.arglead
endfunction
"}}}
function! s:Cmdcmpl.get_settledqt(...) "{{{
  let NULL = "\<C-n>"
  let ignorepat = a:0 ? a:1 : self.funcopts.optbgnpat. '\S'
  let ignorepat = ignorepat=='' ? NULL : ignorepat
  if has_key(self.save_settlednums, ignorepat)
    return self.save_settlednums[ignorepat]
  end
  let transient = copy(self.leftwords)
  if ignorepat != NULL
    call filter(transient, 'v:val !~# ignorepat')
  end
  let ret = len(transient)-1
  let self.save_settlednums[ignorepat] = self.is_on_edge ? ret : ret-1
  return self.save_settlednums[ignorepat]
endfunction
"}}}
function! s:Cmdcmpl.should_optcmpl() "{{{
  let pat = self.funcopts.optbgnpat
  return pat!='' && self.arglead =~# pat
endfunction
"}}}
function! s:Cmdcmpl.is_matched(pat) "{{{
  return self.arglead =~# a:pat
endfunction
"}}}
function! s:Cmdcmpl.match_arg(pat, ...) "{{{
  return s:_match_arg(a:pat, a:000, self.beens)
endfunction
"}}}
function! s:Cmdcmpl.match_args(pat) "{{{
  return s:_match_args(a:pat, copy(self.beens))
endfunction
"}}}
function! s:Cmdcmpl.match_leftarg(pat, ...) "{{{
  return s:_match_arg(a:pat, a:000, self.leftwords)
endfunction
"}}}
function! s:Cmdcmpl.match_leftargs(pat) "{{{
  return s:_match_args(a:pat, copy(self.leftwords))
endfunction
"}}}
function! s:Cmdcmpl.mill_by_arglead(candidates) "{{{
  return filter(a:candidates, 'v:val =~ "^".self.arglead')
endfunction
"}}}
function! s:Cmdcmpl.mill_inputed(candidates, ...) "{{{
  let reuses = get(a:, 1, [])
  let beens = filter(copy(self.beens), 'index(reuses, v:val)==-1')
  return filter(a:candidates, 'index(beens, v:val)==-1')
endfunction
"}}}
function! s:Cmdcmpl.mill_conflicted(candidates, ...) "{{{
  let conflicts = a:0 ? a:1 : get(self.funcopts, 'conflicts', [])
  for confs in conflicts
    for conf in confs
      if index(self.beens, conf)!=-1
        call filter(a:candidates, 'index(confs, v:val)==-1')
        break
      end
    endfor
  endfor
  return a:candidates
endfunction
"}}}
function! s:Cmdcmpl.mill_candidates(candidates, ...) "{{{
  let conflicts = has_key(a:, 1) ? a:1 : get(self.funcopts, 'conflicts', [])
  let reuses = get(a:, 2, [])
  call self.mill_conflicted(a:candidates, conflicts)
  if type(reuses)!=s:TYPE_LIST
    return self.mill_by_arglead(a:candidates)
  end
  let beens = filter(copy(self.beens), 'index(reuses, v:val)==-1')
  return filter(a:candidates, 'v:val =~ "^".self.arglead && index(beens, v:val)==-1')
endfunction
"}}}


"--------------------------------------
let s:CmdParser = {}
function! lim#cmddef#newCmdParser(args, ...) "{{{
  let obj = copy(s:CmdParser)
  let funcopts = get(a:, 1, {})
  let obj.longbgnpat = get(funcopts, 'longbgnpat', '--')
  let obj.shortbgnpat = get(funcopts, 'shortbgnpat', '-')
  let obj.assignpat = get(funcopts, 'assignpat', '=')
  let obj.endpat = '\%('. obj.assignpat. '\(.*\)\)\?$'
  let obj.args = a:args
  let obj.args_original = copy(a:args)
  let pat = '^'. obj.longbgnpat
  let obj.args_exceptlong = filter(copy(a:args), 'v:val !~# pat')
  return obj
endfunction
"}}}
function! s:CmdParser.match_arg(pat, ...) "{{{
  return s:_match_arg(a:pat, a:000, self.args)
endfunction
"}}}
function! s:CmdParser.match_args(pat) "{{{
  return s:_match_args(a:pat, copy(self.args))
endfunction
"}}}
function! s:CmdParser.filter(pat) "{{{
  return filter(self.args, pat)
endfunction
"}}}
function! s:CmdParser.parse_options(optdict) "{{{
  let ret = {}
  for [key, val] in items(a:optdict)
    let valdict = type(val)!=s:TYPE_DICT ? {'default': val} : val
    unlet val
    let optpats = has_key(valdict, 'pats') ? valdict.pats : [self.longbgnpat. key]
    let optval = self._get_optval(optpats)
    let ret[key] = optval=='' ? get(valdict, 'default', 0) : optval
  endfor
  return ret
endfunction
"}}}

function! s:CmdParser._get_optval(optpats) "{{{
  for pat in a:optpats
    if pat =~# '^'.self.longbgnpat || pat !~# '^'.self.shortbgnpat.'.$'
      let i = match(self.args, '^'.pat. self.endpat)
      if i!=-1
        return self._solve_optval(substitute(remove(self.args, i), '^'.pat, '', ''))
      end
    else
      let shortchr = matchstr(pat, '^'.self.shortbgnpat.'\zs.$')
      let i = match(self.args_exceptlong, '^'.self.shortbgnpat.'.\{-}'.shortchr.'.\{-}'.endpat)
      if i!=-1
        let optval = matchstr(self.args[i], shortchr. '\zs'. self.assignpat.'.*$')
        let self.args[i] = substitute(self.args[i], '^'. self.shortbgnpat.'.\{-}\zs'.shortchr. (optval=='' ? '' : self.assignpat.'.*'), '', '')
        if self.args[i] ==# shortbgnpat
          unlet self.args[i]
        end
        return self._solve_optval(optval)
      end
    end
  endfor
  return ''
endfunction
"}}}
function! s:CmdParser._solve_optval(optval) "{{{
  return a:optval=='' ? 1 : matchstr(a:optval, '^'. self.assignpat. '\zs.*')
endfunction
"}}}


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
