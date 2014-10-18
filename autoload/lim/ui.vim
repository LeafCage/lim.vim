if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
"Misc:
function! s:_get_nemustrokes_pats(strokedefs, crrinput) "{{{
  let inputlen = strlen(a:crrinput)
  let seen = {}
  let nextstrokes_str = ''
  let multistrokes_str = ''
  for strokedef in a:strokedefs
    if strokedef !~# '^'.a:crrinput
      continue
    end
    let c = strokedef[inputlen]
    if c==''
      continue
    elseif has_key(seen, c)
      if multistrokes_str !~# c | let multistrokes_str .= c | end
    else
      let nextstrokes_str .= c
      let seen[c] = 1
    end
  endfor
  let nextstrokes_pat = '['. substitute(nextstrokes_str, '[\]\^\-\\]', '\\\0', 'g'). ']'
  let multistrokes_pat = '['. substitute(multistrokes_str, '[\]\^\-\\]', '\\\0', 'g'). ']'
  return [nextstrokes_pat, multistrokes_pat]
endfunction
"}}}
function! s:_envimkeybind(str) "{{{
  try
    let ret = has_key(s:, 'disable_str2vimkeybind') ? a:str : lim#str2vimkeybind#str2vimkeybind(a:str)
    return ret
  catch /E117:/
    let s:disable_str2vimkeybind = 1
    return a:str
  endtry
endfunction
"}}}

let s:Inputs = {}
function! s:newInputs(keys) "{{{
  let obj = copy(s:Inputs)
  let obj.crrinput = ''
  let obj.keys = a:keys
  return obj
endfunction
"}}}
function! s:Inputs.receive() "{{{
    let [self.nextstrokes_pat, self.multistrokes_pat] = s:_get_nemustrokes_pats(self.keys, self.crrinput)
    let char = nr2char(getchar())
    let self.crrinput .= char
    return char
endfunction
"}}}
function! s:Inputs.is_specifiable(char) "{{{
  if !self._has_nextdef(a:char)
    if self._has_pastmatch()
      return 1
    end
    let self.crrinput = ''
  elseif !self._has_nextmultidef() && index(self.keys, self.crrinput)!=-1
    return 1
  end
endfunction
"}}}
function! s:Inputs._has_nextdef(char) "{{{
  return a:char =~# self.nextstrokes_pat
endfunction
"}}}
function! s:Inputs._has_pastmatch() "{{{
  let pastinput = self.crrinput[-2]
  return index(self.keys, pastinput)!=-1
endfunction
"}}}
function! s:Inputs._has_nextmultidef() "{{{
  return self.crrinput =~# self.multistrokes_pat
endfunction
"}}}
function! s:Inputs.get_crrinput() "{{{
  return self.crrinput
endfunction
"}}}


"=============================================================================
"Main:
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})
function! lim#ui#select(prompt, choices, ...) "{{{
  let funcopts = get(a:, 1, {})
  if empty(a:choices)
    return []
  end
  echo a:prompt
  let choices = type(a:choices)==s:TYPE_DICT ? sort(items(a:choices)) : a:choices
  if get(funcopts, 'show_choices', 1)
    call s:_show_choices(choices)
  end
  let keys = map(copy(choices), 'v:val[0]')
  let cancel_inputs = get(funcopts, 'cancel_inputs', ["\<Esc>"]) + ["\<C-c>"]
  let inputs = s:newInputs(keys)
  while 1
    let char = inputs.receive()
    if index(cancel_inputs, char)!=-1
      redraw!
      if has_key(funcopts, 'throw_on_canceled') && (type(funcopts.throw_on_canceled)==s:TYPE_LIST ? index(funcopts.throw_on_canceled, char)!=-1 : funcopts.throw_on_canceled)
        throw 'select: canceled'
      end
      return []
    elseif inputs.is_specifiable(char)
      break
    end
  endwhile
  redraw!
  let input = inputs.get_crrinput()
  let idx = match(choices, "^\\V['". escape(input, '\'). "', ")
  let determ = choices[idx]
  call s:_solve_caption(determ)
  return determ
endfunctio
"}}}
function! s:_show_choices(choices) "{{{
  for choice in a:choices
    unlet! val
    let val = choice[1]
    let type = type(val)
    if type==s:TYPE_LIST
      let t = get(val, 0, '') | unlet val | let val = t | let type = type(val)
    end
    if type!=s:TYPE_DICT
      echo s:_envimkeybind(choice[0]) ':' val
      continue
    elseif get(val, 'is_hidden', 0) || !has_key(val, 'caption')
      continue
    end
    echo s:_envimkeybind(choice[0]) ':' val.caption
  endfor
endfunction
"}}}
function! s:_solve_caption(determ) "{{{
  let val = a:determ[1]
  let type = type(val)
  if type==s:TYPE_LIST
    let t = get(val, 0, '')
    call extend(a:determ, val[1:])
    unlet val
    let a:determ[1] = t
    let val = t
    let type = type(val)
  end
  if type==s:TYPE_DICT
    if has_key(val, 'throw')
      exe 'throw' val.throw
    end
    let a:determ[1] = get(val, 'caption', '')
  end
endfunction
"}}}

function! lim#ui#keybind(binddefs) "{{{
  let bindacts= {}
  for [act, binds] in items(a:binddefs)
    for bind in binds
      let bindacts[bind] = act
    endfor
  endfor
  let inputs = s:newInputs(key(bindacts))
  while 1
    let char = inputs.receive()
    if !has_key(bindacts, "\<C-c>") && char=="\<C-c>"
      return ''
    elseif inputs.is_specifiable(char)
      break
    end
  endwhile
  return bindacts[inputs.get_crrinput()]
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
