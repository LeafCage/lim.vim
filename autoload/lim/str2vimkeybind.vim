if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
"Misc:
let s:prefix = {"\<C-b>": 'self._parse_prefix_Cb(a:i)', "\<C-d>": '"<C-"', "\<C-f>": 'self._parse_prefix_Cf(a:i)', "\<C-h>": '"<M-"', "\<C-l>": '"<C-M-"',}
let s:prefix_2byte = {'64514': '<S-', '64516': '<C-', '64518': '<S-C-', '64520': '<M-', '64522': '<S-M-', '64524': '<C-M-', '64526': '<S-C-M-'}
let s:solo = {"\<Esc>": '<Esc>', "\<CR>": '<CR>', ' ': '<Space>', "\<Tab>": '<Tab>', "\<C-_>": '<C-_>', "\<M-_>": '<M-_>', "\<C-^>": '<C-^>', "\<M-^>": '<M-^>', "\<C-]>": '<C-]>', "\<M-[>": '<M-[>', "\<M-]>": '<M-]>', "\<M-,>": '<M-,>', "\<M-.>": '<M-.>', "\<M-0>": '<M-0>', "\<M-1>": '<M-1>', "\<M-2>": '<M-2>', "\<M-3>": '<M-3>', "\<M-4>": '<M-4>', "\<M-5>": '<M-5>', "\<M-6>": '<M-6>', "\<M-7>": '<M-7>', "\<M-8>": '<M-8>', "\<M-9>": '<M-9>', "\<C-a>": '<C-a>', "\<C-b>": '<C-b>', "\<C-c>": '<C-c>', "\<C-d>": '<C-d>', "\<C-e>": '<C-e>', "\<C-f>": '<C-f>', "\<C-g>": '<C-g>', "\<C-h>": '<C-h>', "\<C-j>": '<C-j>', "\<C-k>": '<C-k>', "\<C-l>": '<C-l>', "\<C-n>": '<C-n>', "\<C-o>": '<C-o>', "\<C-p>": '<C-p>', "\<C-q>": '<C-q>', "\<C-r>": '<C-r>', "\<C-s>": '<C-s>', "\<C-t>": '<C-t>', "\<C-u>": '<C-u>', "\<C-v>": '<C-v>', "\<C-w>": '<C-w>', "\<C-x>": '<C-x>', "\<C-y>": '<C-y>', "\<C-z>": '<C-z>', "\<M-a>": '<M-a>', "\<M-b>": '<M-b>', "\<M-c>": '<M-c>', "\<M-d>": '<M-d>', "\<M-e>": '<M-e>', "\<M-f>": '<M-f>', "\<M-g>": '<M-g>', "\<M-h>": '<M-h>', "\<M-i>": '<M-i>', "\<M-j>": '<M-j>', "\<M-k>": '<M-k>', "\<M-l>": '<M-l>', "\<M-m>": '<M-m>', "\<M-n>": '<M-n>', "\<M-o>": '<M-o>', "\<M-p>": '<M-p>', "\<M-q>": '<M-q>', "\<M-r>": '<M-r>', "\<M-s>": '<M-s>', "\<M-t>": '<M-t>', "\<M-u>": '<M-u>', "\<M-v>": '<M-v>', "\<M-w>": '<M-w>', "\<M-x>": '<M-x>', "\<M-y>": '<M-y>', "\<M-z>": '<M-z>'}
let s:cmb = {'kb': '<BS>', 'kD': '<Del>', '*4': '<S-Del>', 'kB': '<S-Tab>', 'kl': '<Left>', 'kr': '<Right>', 'ku': '<Up>', 'kd': '<Down>', '#4': '<S-Left>', '%i': '<S-Right>', "\xfd\<C-d>": '<S-Up>', "\xfd\<C-e>": '<S-Down>', "\xfdU": '<C-Left>', "\xfdV": '<C-Right>', "\xffX": '<C-@>', 'k1': '<F1>', 'k2': '<F2>', 'k3': '<F3>', 'k4': '<F4>', 'k5': '<F5>', 'k6': '<F6>', 'k7': '<F7>', 'k8': '<F8>', 'k9': '<F9>', 'k;': '<F10>', 'F1': '<F11>', 'F2': '<F12>', "\xfd\<C-f>": '<S-F1>', "\xfd\<C-g>": '<S-F2>', "\xfd\<C-h>": '<S-F3>', "\xfd\<C-i>": '<S-F4>', "\xfd\<C-j>": '<S-F5>', "\xfd\<C-k>": '<S-F6>', "\xfd\<C-l>": '<S-F7>', "\xfd\<C-m>": '<S-F8>', "\xfd\<C-n>": '<S-F9>', "\xfd\<C-o>": '<S-F10>', "\xfd\<C-p>": '<S-F11>', "\xfd\<C-q>": '<S-F12>', }

let s:Parser = {}
function! s:newParser(lis) "{{{
  let obj = copy(s:Parser)
  let obj.lis = a:lis
  let obj.len = len(a:lis)
  let obj.has_prefix = 0
  let obj.parse_prefix = &encoding =~ 'cp932\|euc\|sjis' ? function('s:_parse_prefix_2byte') : function('s:_parse_prefix')
  return obj
endfunction
"}}}
function! s:Parser.parse_other(i) "{{{
  let ret = self.lis[a:i]==nr2char(137) ? '<M-Tab>' : get(s:solo, self.lis[a:i], self.lis[a:i])
  if self.has_prefix
    let ret = len(ret)>1 ? ret[1:] : ret.'>'
  end
  let self.has_prefix = 0
  return ret
endfunction
"}}}
function! s:Parser._parse_prefix_Cb(i) "{{{
  let n = char2nr(self.lis[a:i+1])
  if n > 128
    return '<S-'
  end
  let self.lis[a:i+1] = nr2char(n-128)
  return '<S-M-'
endfunction
"}}}
function! s:Parser._parse_prefix_Cf(i) "{{{
  let n = char2nr(self.lis[a:i+1])
  if n < 128
    return '<S-C-'
  end
  let self.lis[a:i+1] = nr2char(n-128)
  return '<S-C-M-'
endfunction
"}}}
function! s:_parse_prefix(i) dict "{{{
  let subs = remove(self.lis, a:i+1, a:i+2)
  let self.len -= 2
  if subs[0] == "\xfc"
    let self.has_prefix = 1
    return has_key(s:prefix, subs[1]) ? eval(s:prefix[subs[1]]) : '<'.subs[1]
  end
  let key = subs[0]. subs[1]
  if has_key(s:cmb, key)
    let b = s:cmb[key]
    let ret = self.has_prefix ? b[1:] : b
  else
    let ret = key
  end
  let self.has_prefix = 0
  return ret
endfunction
"}}}
function! s:_parse_prefix_2byte(i) dict "{{{
  let sub = remove(self.lis, a:i+1)
  let subnr = char2nr(sub)
  let self.len -= 1
  if has_key(s:prefix_2byte, subnr)
    let self.has_prefix = 1
    return s:prefix_2byte[subnr]
  end
  let key = sub. remove(self.lis, a:i+1)
  let self.len -= 1
  if has_key(s:cmb, key)
    let b = s:cmb[key]
    let ret = self.has_prefix ? b[1:] : b
  else
    let ret = key
  end
  let self.has_prefix = 0
  return ret
endfunction
"}}}


"======================================
"Public:
function! lim#str2vimkeybind#str2vimkeybind(stroke) "{{{
  let lis = split(a:stroke, '\zs')
  let parser = s:newParser(lis)
  let i = 0
  while i < parser.len
    if lis[i]=="\x80"
      let lis[i] = parser.parse_prefix(i)
    else
      let lis[i] = parser.parse_other(i)
    end
    let i += 1
  endwhile
  return join(lis, '')
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
