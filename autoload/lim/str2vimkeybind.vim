if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
"Public:
let s:prefix = {"\<C-b>": '<S-', "\<C-d>": '<C-', "\<C-h>": '<M-', "\<C-l>": '<C-M-'}
let s:solo = {"\<Esc>": '<Esc>', "\<CR>": '<CR>', ' ': '<Space>', "\<Tab>": '<Tab>', "\<C-_>": '<C-_>', "\<C-^>": '<C-^>', "\<C-]>": '<C-]>', "\<C-a>": '<C-a>', "\<C-b>": '<C-b>', "\<C-c>": '<C-c>', "\<C-d>": '<C-d>', "\<C-e>": '<C-e>', "\<C-f>": '<C-f>', "\<C-g>": '<C-g>', "\<C-h>": '<C-h>', "\<C-j>": '<C-j>', "\<C-k>": '<C-k>', "\<C-l>": '<C-l>', "\<C-n>": '<C-n>', "\<C-o>": '<C-o>', "\<C-p>": '<C-p>', "\<C-q>": '<C-q>', "\<C-r>": '<C-r>', "\<C-s>": '<C-s>', "\<C-t>": '<C-t>', "\<C-u>": '<C-u>', "\<C-v>": '<C-v>', "\<C-w>": '<C-w>', "\<C-x>": '<C-x>', "\<C-y>": '<C-y>', "\<C-z>": '<C-z>'}
let s:cmb = {'kb': '<BS>', 'kD': '<Del>', 'kB': '<S-Tab>', "\xffX": '<C-@>', 'k1': '<F1>', 'k2': '<F2>', 'k3': '<F3>', 'k4': '<F4>', 'k5': '<F5>', 'k6': '<F6>', 'k7': '<F7>', 'k8': '<F8>', 'k9': '<F9>', 'k;': '<F10>', 'F1': '<F11>', 'F2': '<F12>', "\xfd\<C-f>": '<S-F1>', "\xfd\<C-g>": '<S-F2>', "\xfd\<C-h>": '<S-F3>', "\xfd\<C-i>": '<S-F4>', "\xfd\<C-j>": '<S-F5>', "\xfd\<C-k>": '<S-F6>', "\xfd\<C-l>": '<S-F7>', "\xfd\<C-m>": '<S-F8>', "\xfd\<C-n>": '<S-F9>', "\xfd\<C-o>": '<S-F10>', "\xfd\<C-p>": '<S-F11>', "\xfd\<C-q>": '<S-F12>', }
"TODO: 'encoding'が utf8 以外の時にも対応
function! lim#str2vimkeybind#str2vimkeybind(stroke) "{{{
  let lis = split(a:stroke, '\zs')
  let len = len(lis)
  let i = 0
  let has_prefix = 0
  while i < len
    if lis[i]=="\x80"
      let frgs = remove(lis, i+1, i+2)
      let len -= 2
      if frgs[0] == "\xfc"
        let lis[i] = get(s:prefix, frgs[1], '<'.frgs[1])
        let has_prefix = 1
        let i +=1
        continue
      end
      let lis[i] = get(s:cmb, frgs[0]. frgs[1], frgs[0]. frgs[1])
      if has_prefix
        let lis[i] = lis[i][1:]
      end
    else
      let lis[i] = lis[i]==nr2char(137) ? '<M-Tab>' : get(s:solo, lis[i], lis[i])
      if has_prefix
        let lis[i] = len(lis[i])>1 ? lis[i][1:] : lis[i].'>'
      end
    end
    let has_prefix = 0
    let i += 1
  endwhile
  return join(lis, '')
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
