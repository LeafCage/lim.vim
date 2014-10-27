if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})
let s:TYPE_STR = type('')

"Misc:
let s:func = {}
function! s:func._get_optignorepat() "{{{
  return '^\%('.self.shortoptbgn.'\|'.self.longoptbgn.'\)\S'
endfunction
"}}}
function! s:func._get_arg(pat, variadic, list) dict "{{{
  let type = type(a:pat)
  if type==s:TYPE_STR
    let default = get(a:variadic, 0, '')
    let idx = match(a:list, a:pat)
    return idx==-1 ? default : a:list[i]
  elseif type==s:TYPE_LIST
    let [idx, default] = [get(a:variadic, 0, 0), get(a:variadic, 1, '')]
    return get(filter(copy(a:list), 'index(a:pat, v:val)!=-1'), idx, default)
  end
  let default = get(a:variadic, -1, '')
  let list = copy(a:list)
  if len(a:variadic)>1
    let ignorepat = self._get_optignorepat()
    call filter(list, 'v:val !~# ignorepat')
  end
  return get(list, pat, default)
endfunction
"}}}
function! s:_match_args(pat, list) "{{{
  if type(a:pat)==s:TYPE_LIST
    return filter(a:list, 'index(a:pat, v:val)!=-1')
  end
  return filter(a:list, 'v:val =~ a:pat')
endfunction
"}}}

let s:Classifier = {}
function! s:newClassifier(candidates, longoptbgn, shortoptbgn) "{{{
  let obj = copy(s:Classifier)
  let obj.candidates = a:candidates
  let obj.longoptbgn = '^'.a:longoptbgn
  let obj.shortoptbgn = '^'.a:shortoptbgn
  let obj.short = []
  let obj.long = []
  let obj.other = []
  return obj
endfunction
"}}}
function! s:Classifier.set_classified_candies(...) "{{{
  let self.beens = get(a:, 1, [])
  for candy in self.candidates
    call self._classify_candy(candy)
    unlet candy
  endfor
endfunction
"}}}
function! s:Classifier.join_candidates(order, sort) "{{{
  for elm in ['long', 'short', 'other']
    if get(a:sort, elm, -1) != -1
      exe 'call sort(self[elm], '. (a:sort[elm] ? a:sort[elm] : ''). ')'
    end
  endfor
  return self[a:order[0]] + self[a:order[1]] + self[a:order[2]]
endfunction
"}}}
function! s:Classifier._classify_candy(candy) "{{{
  if type(a:candy)!=s:TYPE_LIST
    if index(self.beens, a:candy)==-1
      call self._add(a:candy)
    end
    return
  end
  for cand in a:candy
    if index(self.beens, cand)!=-1
      return
    end
  endfor
  for cand in a:candy
    call self._add(cand)
  endfor
endfunction
"}}}
function! s:Classifier._add(candy) "{{{
   if a:candy =~ self.longoptbgn
     return add(self.long, a:candy)
   elseif a:candy =~ self.shortoptbgn
     return add(self.short, a:candy)
   else
     return add(self.other, a:candy)
   end
endfunction
"}}}


"=============================================================================
"Main:
let s:Cmdcmpl = {}
function! lim#cmddef#newCmdcmpl(cmdline, cursorpos, ...) abort "{{{
  let obj = copy(s:Cmdcmpl)
  let funcopts = get(a:, 1, {})
  let obj.longoptbgn = get(funcopts, 'longoptbgn', '--')
  let obj.shortoptbgn = get(funcopts, 'shortoptbgn', '-')
  let obj.order = get(funcopts, 'order', ['long', 'short', 'other'])
  let obj.sort = get(funcopts, 'sort', {'long': 0, 'short': 0, 'other': 0})
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
let s:Cmdcmpl._get_optignorepat = s:func._get_optignorepat
let s:Cmdcmpl._get_arg = s:func._get_arg
function! s:Cmdcmpl.get_arglead() "{{{
  return self.arglead
endfunction
"}}}
function! s:Cmdcmpl.get_settlednum(...) "{{{
  let NULL = "\<C-n>"
  let ignorepat = a:0 ? a:1 : self._get_optignorepat()
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
  let pat = '^'.self.shortoptbgn.'\|^'.self.longoptbgn
  return pat!='^\|^' && self.arglead =~# pat
endfunction
"}}}
function! s:Cmdcmpl.is_matched(pat) "{{{
  return self.arglead =~# a:pat
endfunction
"}}}
function! s:Cmdcmpl.get_arg(pat, ...) "{{{
  return self._get_arg(a:pat, a:000, self.beens)
endfunction
"}}}
function! s:Cmdcmpl.match_args(pat) "{{{
  return s:_match_args(a:pat, copy(self.beens))
endfunction
"}}}
function! s:Cmdcmpl.get_leftarg(pat, ...) "{{{
  return self._get_arg(a:pat, a:000, self.leftwords)
endfunction
"}}}
function! s:Cmdcmpl.match_leftargs(pat) "{{{
  return s:_match_args(a:pat, copy(self.leftwords))
endfunction
"}}}
function! s:Cmdcmpl.mill_candidates(candidates, ...) "{{{
  let matchtype = 'forward'
  let funcopts = {}
  if a:0
    exe 'let' (type(a:1)==s:TYPE_STR ? 'matchtype' : 'funcopt') '= a:1'
    if a:0>1
      exe 'let' (type(a:2)==s:TYPE_STR ? 'matchtype' : 'funcopt') '= a:2'
    end
  end
  let reuses = get(funcopts, 'reuses', [])
  let order = get(funcopts, 'order', self.order)
  let sort = get(funcopts, 'sort', self.sort)
  let classifier = s:newClassifier(a:candidates, self.longoptbgn, self.shortoptbgn)
  if type(reuses)==s:TYPE_LIST
    let beens = filter(copy(self.beens), 'index(reuses, v:val)==-1')
    call classifier.set_classified_candies(beens)
  else
    "TODO
    call classifier.set_classified_candies()
  end
  let candidates = classifier.join_candidates(order, sort)
  try
    let candidates = self['_millby_arglead_'.matchtype](candidates)
  catch /E716:/
    echoerr 'lim/cmddef: invalid argument > "'. matchtype. '"'
  endtry
  return candidates
endfunction
"}}}
function! s:Cmdcmpl._millby_arglead_none(candidates) "{{{
  return a:candidates
endfunction
"}}}
function! s:Cmdcmpl._millby_arglead_forward(candidates) "{{{
  return filter(a:candidates, 'v:val =~ "^".self.arglead')
endfunction
"}}}
function! s:Cmdcmpl._millby_arglead_backword(candidates) "{{{
  return filter(a:candidates, 'v:val =~ self.arglead."$"')
endfunction
"}}}
function! s:Cmdcmpl._millby_arglead_partial(candidates) "{{{
  return filter(a:candidates, 'v:val =~ self.arglead')
endfunction
"}}}
function! s:Cmdcmpl._millby_arglead_exact(candidates) "{{{
  return filter(a:candidates, 'v:val == self.arglead')
endfunction
"}}}


"--------------------------------------
let s:CmdParser = {}
function! lim#cmddef#newCmdParser(args, ...) "{{{
  let obj = copy(s:CmdParser)
  let funcopts = get(a:, 1, {})
  let obj.longoptbgn = get(funcopts, 'longoptbgn', '--')
  let obj.shortoptbgn = get(funcopts, 'shortoptbgn', '-')
  let obj.assignpat = get(funcopts, 'assignpat', '=')
  let obj.endpat = '\%('. obj.assignpat. '\(.*\)\)\?$'
  let obj.args = a:args
  let obj.args_original = copy(a:args)
  let pat = '^'. obj.longoptbgn
  let obj.args_exceptlong = filter(copy(a:args), 'v:val !~# pat')
  return obj
endfunction
"}}}
let s:CmdParser._get_optignorepat = s:func._get_optignorepat
let s:CmdParser._get_arg = s:func._get_arg
function! s:CmdParser.get_arg(pat, ...) "{{{
  return s:_get_arg(a:pat, a:000, self.args)
endfunction
"}}}
function! s:CmdParser.match_args(pat) "{{{
  return s:_match_args(a:pat, copy(self.args))
endfunction
"}}}
function! s:CmdParser.filter(pat, ...) "{{{
  let __cmpparser_args__ = self.args
  if a:0
    for __cmpparser_key__ in keys(a:1)
      exe printf('let %s = a:1[__cmpparser_key__]', __cmpparser_key__)
    endfor
  end
  return filter(__cmpparser_args__, a:pat)
endfunction
"}}}
function! s:CmdParser.divide(pat, ...) "{{{
  let way = get(a:, 1, 'sep')
  let self.len = len(self.args)
  try
    let ret = self['_divide_'. way](a:pat)
  catch /E716/
    echoerr 'CmdParser: 無効な引数です > "'. way. '"'
    return self.arg
  endtry
  return ret==[[]] ? [] : ret
endfunction
"}}}
function! s:CmdParser.parse_options(optdict) "{{{
  let ret = {}
  for [key, val] in items(a:optdict)
    let valdict = type(val)!=s:TYPE_DICT ? {'default': val} : val
    unlet val
    let optpats = has_key(valdict, 'pats') ? valdict.pats : [self.longoptbgn. key]
    let optval = self._get_optval(optpats)
    let ret[key] = optval=='' ? get(valdict, 'default', 0) : optval
  endfor
  return ret
endfunction
"}}}

function! s:CmdParser._get_optval(optpats) "{{{
  for pat in a:optpats
    if pat =~# '^'.self.longoptbgn || pat !~# '^'.self.shortoptbgn.'.$'
      let i = match(self.args, '^'.pat. self.endpat)
      if i!=-1
        return self._solve_optval(substitute(remove(self.args, i), '^'.pat, '', ''))
      end
    else
      let shortchr = matchstr(pat, '^'.self.shortoptbgn.'\zs.$')
      let i = match(self.args_exceptlong, '^'.self.shortoptbgn.'.\{-}'.shortchr.'.\{-}'.endpat)
      if i!=-1
        let optval = matchstr(self.args[i], shortchr. '\zs'. self.assignpat.'.*$')
        let self.args[i] = substitute(self.args[i], '^'. self.shortoptbgn.'.\{-}\zs'.shortchr. (optval=='' ? '' : self.assignpat.'.*'), '', '')
        if self.args[i] ==# shortoptbgn
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
function! s:CmdParser._get_firstmatch_idx(patlist, bgnidx) "{{{
  let i = a:bgnidx
  while i < self.len
    if index(a:patlist, self.args[i])!=-1
      return i
    end
    let i+=1
  endwhile
  return -1
endfunction
"}}}
function! s:CmdParser._divide_start(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i+1)' : 'match(self.args, a:pat, i+1)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    call add(ret, self.args[i :j-1])
    let i = j
    let j = eval(expr)
  endwhile
  call add(ret, self.args[i :-1])
  return ret
endfunction
"}}}
function! s:CmdParser._divide_sep(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i)' : 'match(self.args, a:pat, i)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    if j-i != 0
      call add(ret, self.args[i :j-1])
    end
    let i = j+1
    let j = eval(expr)
  endwhile
  if i < self.len
    call add(ret, self.args[i :-1])
  end
  return ret
endfunction
"}}}
function! s:CmdParser._divide_stop(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i)' : 'match(self.args, a:pat, i)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    call add(ret, self.args[i :j])
    let i = j+1
    let j = eval(expr)
  endwhile
  if i < self.len
    call add(ret, self.args[i :-1])
  end
  return ret
endfunction
"}}}


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
