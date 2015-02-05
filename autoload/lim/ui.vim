if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])

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
function! s:_expand_keycodes(str) "{{{
  return substitute(a:str, '<\S\{-1,}>', '\=eval(''"\''. submatch(0). ''"'')', 'g')
endfunction
"}}}
function! s:_envimkeycodes(str) "{{{
  try
    let ret = has_key(s:, 'disable_keynotation') ? a:str : lim#keynotation#encode(a:str)
    return ret
  catch /E117:/
    let s:disable_keynotation = 1
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
function! lim#ui#select(prompt, choices, ...) "{{{
  let behavior = a:0 ? a:1 : {}
  if a:choices==[]
    return []
  end
  echo a:prompt
  if !get(behavior, 'silent', 0)
    call s:_show_choices(a:choices, get(behavior, 'sort', 0))
  end
  let cancel_inputs = get(behavior, 'cancel_inputs', ["\<Esc>", "\<C-c>"])
  if cancel_inputs==[]
    call add(cancel_inputs, "\<C-c>")
  end
  let tmp = get(behavior, 'error_inputs', [])
  let error_inputs = type(tmp)==s:TYPE_LIST ? tmp : tmp ? cancel_inputs : []
  let dict = s:_get_choicesdict(a:choices, get(behavior, 'expand_keycodes', 0))
  let inputs = s:newInputs(keys(dict))
  while 1
    let char = inputs.receive()
    if index(error_inputs, char)!=-1
      redraw!
      throw printf('select: inputed "%s"', s:_envimkeycodes(char))
    elseif index(cancel_inputs, char)!=-1
      redraw!
      return []
    elseif inputs.is_specifiable(char)
      break
    end
  endwhile
  redraw!
  let input = inputs.get_crrinput()
  return dict[input]
endfunctio
"}}}
function! s:_show_choices(choices, sort_choices) "{{{
  let mess = []
  for choice in a:choices
    if empty(get(choice, 0, '')) || get(choice, 1, '')==''
      continue
    end
    if type(choice[0])==s:TYPE_LIST
      let choices = copy(choice[0])
      if a:sort_choices
        call sort(choices)
      end
      let input = join(map(choices, 's:_envimkeycodes(v:val)'), ', ')
    else
      let input = s:_envimkeycodes(choice[0])
    end
    call add(mess, printf('%-6s: %s', input, choice[1]))
  endfor
  if a:sort_choices
    call sort(mess, 1)
  end
  for mes in mess
    echo mes
  endfor
  echon ' '
endfunction
"}}}
function! s:_get_choicesdict(choices, expand_keycodes) "{{{
  let dict = {}
  for cho in a:choices
    if type(cho[0])==s:TYPE_LIST
      for c in cho[0]
        let chr = a:expand_keycodes ? s:_expand_keycodes(c) : c
        if !(chr=='' || has_key(dict, chr))
          let dict[chr] = insert(cho[1:], c)
        end
      endfor
    else
      let chr = a:expand_keycodes ? s:_expand_keycodes(cho[0]) : cho[0]
      if !(chr=='' || has_key(dict, chr))
        let dict[chr] = insert(cho[1:], cho[0])
      end
    end
  endfor
  return dict
endfunction
"}}}

function! lim#ui#keybind(binddefs) "{{{
  return s:keybind(a:binddefs, 0)
endfunction
"}}}
function! lim#ui#expand_keybind(binddefs) "{{{
  return s:keybind(a:binddefs, 1)
endfunction
"}}}
function! s:keybind(binddefs, expand_keycodes) "{{{
  let bindacts = a:expand_keycodes ? s:_get_bindacts_by_vimkeynotation(a:binddefs) : s:_get_bindacts(a:binddefs)
  let inputs = s:newInputs(keys(bindacts))
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
function! s:_get_bindacts(binddefs) "{{{
  let bindacts= {}
  for [act, binds] in items(a:binddefs)
    for bind in binds
      let bindacts[bind] = act
    endfor
  endfor
  return bindacts
endfunction
"}}}
function! s:_get_bindacts_by_vimkeynotation(binddefs) "{{{
  let bindacts= {}
  for [act, binds] in items(a:binddefs)
    for bind in binds
      let bindacts[s:_expand_keycodes(bind)] = act
    endfor
  endfor
  return bindacts
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
