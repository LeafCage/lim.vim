if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
"Misc:
function! s:_get_rootpath_and_pluginname_of(path) "{{{
  for dir in ['after', 'autoload', 'plugin', 'syntax', 'ftplugin', 'ftdetect']
    let findpath = finddir(dir, a:path. ';**/vimfiles;**/.vim')
    if findpath == ''
      continue
    end
    let rootpath = fnamemodify(findpath, ':p:h:h')
    let pluginname = fnamemodify(rootpath, ':t:r')
    if pluginname =~# '^\%(vimfiles\|\.vim\)$'
      continue
    end
    return [rootpath, pluginname]
  endfor
  return ['', '']
endfunction
"}}}
function! s:_get_actual_pluginname(rootpath) "{{{
  for expr in ['/plugin/*.vim', '/syntax/*.vim', '/autoload/*.vim']
    let file = glob(a:rootpath. expr)
    if file == '' || file =~ "\n"
      continue
    endif
    return fnamemodify(file, ':t:r')
  endfor
  return ''
endfunction
"}}}

let s:Uniqifier = {}
function! s:newUniqifier(list) "{{{
  let obj = copy(s:Uniqifier)
  let obj.list = a:list
  let obj.seens = {}
  return obj
endfunction
"}}}
function! s:Uniqifier._is_firstseen(str) "{{{
  let str = string(a:str)
  if has_key(self.seens, str)
    return 0
  end
  let self.seens[str] = 1
  return 1
endfunction
"}}}
function! s:Uniqifier.mill() "{{{
  return filter(self.list, 'self._is_firstseen(v:val)')
endfunction
"}}}


"=============================================================================
"Vim:
"exコマンドの結果をリスト化して返す
function! lim#misc#get_cmdresults(cmd) "{{{
  let save_vfile = &verbosefile
  set verbosefile=
  redir => result
  silent! execute a:cmd
  redir END
  let &verbosefile = save_vfile
  return split(result, "\n")
endfunction
"}}}

let s:sid_cache = {}
function! lim#misc#get_sid(...) "{{{
  let path = !a:0 ? expand('%:p') : fnamemodify(expand(a:1), ':p:gs?\\?/?')
  if has_key(s:sid_cache, path)
    return s:sid_cache[path]
  endif
  let snames = lim#misc#get_cmdresults('scriptnames')
  call map(snames, 'substitute(v:val, ''\s*\d*\s*:\s*\(.*\)'', ''\=expand(submatch(1))'', "")')
  let sid = index(snames, path)+1
  if !sid
    let s:sid_cache[path] = sid
  endif
  return sid
endfunction
"}}}
function! lim#misc#match_sids(pat) "{{{
  let snames = lim#misc#get_cmdresults('scriptnames')
  let sids = []
  let i = match(snames, escape(a:pat, ' .\'))+1
  while i
    call add(sids, i)
    let i += 1
    let i = match(snames, escape(a:pat, ' .\'), i)+1
  endwhile
  return sids
endfunction
"}}}
function! lim#misc#get_scriptname(sid) "{{{
endfunction
"}}}

"======================================
"Data:
function! lim#misc#uniqify(list) "{{{
  return s:newUniqifier(a:list).mill()
endfunction
"}}}

"======================================
"System:
function! lim#misc#path_encode(path) "{{{
  return substitute(a:path, '[=:/\\]', '\=get({"=": "==", ":": "=-"}, submatch(0), "=+")', 'g')
endfunction
"}}}
function! lim#misc#path_decode(fname) "{{{
  return substitute(a:fname, '==\|=+\|=-', '\={"==": "=", "=-": ":", "=+": "/"}[submatch(0)]', 'g')
endfunction
"}}}


function! lim#misc#get_plugins_root_and_name_and_actualname(path) "{{{
  let [rootpath, pluginname] = s:_get_rootpath_and_pluginname_of(fnamemodify(expand(a:path), ':p'))
  if rootpath == ''
    return [rootpath, pluginname, pluginname]
  end
  let actualname = s:_get_actual_pluginname(rootpath)
  return [rootpath, pluginname, actualname]
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
