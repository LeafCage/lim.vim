command! -nargs=*   LimScriptInfos    for s:msg in lim#misc#get_scriptinfos(<f-args>) | echo s:msg | endfor | unlet! s:msg
