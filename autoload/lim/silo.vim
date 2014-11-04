if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:lim#silo#rootdir = get(g:, 'lim#silo#rootdir', '~/.config/silo')
let s:SEP = "\<C-k>\<Tab>"
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})
let s:TYPE_STR = type('')
let s:CNV = {'m': {'.*': '.\{-}', '.\+': '.\{-1,}'}, 'v': {'.*': '.\{-}', '.+': '.\{-1,}'}}
let s:CNV.M = {'\.\*': '\.\{-}', '\.\+': '\.\{-1,}'}

"Misc:
function! s:_listify(record) "{{{
  return split(a:record, s:SEP)
endfunction
"}}}
function! s:_innerstrify(list) "{{{
  return join(a:list, s:SEP)
endfunction
"}}}
function! s:_is_invalid_fields(fields) "{{{
  return a:fields==[] || match(a:fields, '^\H\|\W')!=-1
endfunction
"}}}
function! s:_fmtmap_by_list(record, fieldidxs) "{{{
  let rec = s:_listify(a:record)
  return map(copy(a:fieldidxs), 'rec[(v:val)]')
endfunction
"}}}
function! s:_fmtmap_by_str(record, fieldsstr, fmt) "{{{
  exe 'let '. a:fieldsstr. ' = s:_listify(a:record)'
  return eval(a:fmt)
endfunction
"}}}
function! s:_inmap_rearrange(record, fieldidxs) "{{{
  let rec = s:_listify(a:record)
  return s:_innerstrify(map(a:fieldidxs, 'rec[(v:val)]'))
endfunction
"}}}
function! s:_inmap_chk_fmt(record, fieldidxs) "{{{
  let rec = s:_listify(a:record)
  return s:_innerstrify(map(a:fieldidxs, 'v:val==-1 ? "" : rec[(v:val)]'))
endfunction
"}}}
function! s:_cnv_magicpat(str, m) "{{{
  let m = a:m
  let ret = m==0 ? [] : [s:_cnv_wildcard(a:str[:m-1], 'm')]
  let n = match(a:str, '\\[vmMV]', m+1)
  while n!=-1
    call add(ret, s:_cnv_wildcard(a:str[m : n-1]))
    let m = n
    let n = match(a:str, '\\[vmMV]', m+1)
  endwhile
  call add(ret, s:_cnv_wildcard(a:str[m :]))
  return join(ret, '')
endfunction
"}}}
function! s:_cnv_wildcard(str, ...) "{{{
  let c = a:0 ? a:1 : a:str[1]
  if c==#'m'
    return substitute(a:str, '\\\@<!\.\%(\*\|\\+\)', '\=s:CNV.m[submatch(0)]', 'g')
  elseif c==#'v'
    return substitute(a:str, '\\\@<!\.[*+]', '\=s:CNV.v[submatch(0)]', 'g')
  end
  return substitute(a:str, '\\.\%(\\\*\|\\+\)', '\=s:CNV.M[submatch(0)]', 'g')
endfunction
"}}}
function! s:_sub_4updatedict(sub) "{{{
  let s:_sub_i += 1
  return get(s:_sub_idx2dest, s:_sub_i, a:sub)
endfunction
"}}}


"=============================================================================
"Public:
let s:Silo = {}
function! lim#silo#newSilo(name, fields, ...) "{{{
  let funcopt = get(a:, 1, {})
  let obj = copy(s:Silo)
  let obj.key = get(funcopt, 'key', '')
  let obj.path = expand(g:lim#silo#rootdir).'/'.a:name
  let obj.dir = fnamemodify(obj.path, ':h')
  if s:_is_invalid_fields(a:fields)
    throw 'silo: invalid fields > '. string(a:fields)
  end
  let obj.fields = a:fields
  let obj.fieldslen = len(a:fields)
  let obj.records = filereadable(obj.path) ? readfile(obj.path) : []
  try
    let oldformat = s:_listify(remove(obj.records, 0))
    if obj._chk_version(oldformat)
      return {}
    end
  catch /E684:/
  endtry
  let obj.chgdtick = 0
  return obj
endfunction
"}}}
function! s:Silo._chk_version(oldformat) "{{{
  if a:oldformat ==# self.fields
    return
  end
  let missingidxs = []
  let i = len(a:oldformat)
  while i
    let i -= 1
    if index(self.fields, a:oldformat[i])==-1
      call add(missingidxs, i)
    end
  endwhile
  let fieldidxs = map(copy(self.fields), 'index(a:oldformat, v:val)')
  if missingidxs!=[]
    let i = len(missingidxs)
    while i
      let i -= 1
      let idx = missingidxs[i]
      if fieldidxs[idx] ==# -1
        let fieldidxs[idx] = idx
        unlet missingidxs[i]
      end
    endwhile
    if missingidxs!=[]
      echoerr 'silo: invalid field >' join(missings, ', ')
      return 1
    end
  end
  call map(self.records, 's:_inmap_chk_fmt(v:val, fieldidxs)')
endfunction
"}}}
function! s:Silo._get_refinepat_by_list(listwhere) "{{{
  if len(a:listwhere)!=self.fieldslen
    throw 'select: invalid condition > '. string(a:listwhere)
  end
  return s:_innerstrify(a:listwhere)
endfunction
"}}}
function! s:Silo._get_refinepat_by_dict(dictwhere) "{{{
  let order = {}
  for [field, val] in items(a:dictwhere)
    let idx = index(self.fields, field)
    if idx==-1
      echoerr 'silo: invalid field name >' field
    end
    let order[idx] = type(val)!=s:TYPE_STR ? string(val) : val
  endfor
  let i = 0
  let pat = '^'
  let save_ignorecase = &ic
  set noic
  try
    while i < self.fieldslen-1
      if has_key(order, i)
        let m = match(order[i], '\\[vmMV]')
        let order[i] = m!=-1 ? s:_cnv_magicpat(order[i], m) : s:_cnv_wildcard(order[i], 'm')
      end
      let pat .= '\%('. get(order, i, '\m.\{-}'). '\)'. s:SEP
      let i += 1
    endwhile
    let pat .= '\%('. get(order, i, '\m.\{-}'). '\)'. '$'
  finally
    let &ic = save_ignorecase
  endtry
  return pat
endfunction
"}}}
function! s:Silo._get_fieldidxs(fmt) "{{{
  let fieldidxs = map(copy(a:fmt), 'index(self.fields, v:val)')
  if index(fieldidxs, -1)!=-1
    throw 'lim-silo: invalid format > '. string(a:fmt)
  end
  return fieldidxs
endfunction
"}}}
function! s:Silo._fmt_by_list(records, fmt) "{{{
  if a:fmt==[]
    return map(a:records, 's:_listify(v:val)')
  end
  let fieldidxs = self._get_fieldidxs(a:fmt)
  if len(a:fmt)==1
    let idx = fieldidxs[0]
    return map(a:records, 's:_listify(v:val)[idx]')
  end
  return map(a:records, 's:_fmtmap_by_list(v:val, fieldidxs)')
endfunction
"}}}
function! s:Silo._fmt_by_str(records, fmt) "{{{
  let idx = index(self.fields, a:fmt)
  if idx==-1
    throw 'lim-silo: invalid format > '. a:fmt
  end
  return map(a:records, 's:_listify(v:val)[idx]')
endfunction
"}}}
function! s:Silo.is_changed() "{{{
  return self.chgdtick
endfunction
"}}}
function! s:Silo.has(where) "{{{
  let type = type(a:where)
  if type==s:TYPE_LIST
    return index(self.records, self._get_refinepat_by_list(a:where))!=-1
  elseif type==s:TYPE_DICT
    return match(self.records, self._get_refinepat_by_dict(a:where))!=-1
  end
  return match(self.records, a:where)!=-1
endfunction
"}}}
function! s:Silo.select(where, ...) "{{{
  let fmt = get(a:, 1, [])
  let type = type(a:where)
  if empty(a:where)
    let refineds = copy(self.records)
  elseif type==s:TYPE_LIST
    let pat = self._get_refinepat_by_list(a:where)
    let refineds = filter(copy(self.records), 'v:val ==# pat')
  elseif type==s:TYPE_DICT
    let pat = self._get_refinepat_by_dict(a:where)
    let refineds = filter(copy(self.records), 'v:val =~# pat')
  else
    let refineds = filter(copy(self.records), 'v:val =~# a:where')
  end
  let type = type(fmt)
  if type==s:TYPE_LIST
    return self._fmt_by_list(refineds, fmt)
  elseif type==s:TYPE_STR
    return self._fmt_by_str(refineds, fmt)
  end
  throw 'silo: invalid format > '. stirng(fmt)
endfunction
"}}}
function! s:Silo.select_distinct(where, ...) "{{{
  let records = call(self.select, [a:where] + a:000, self)
  try
    let ret = lim#misc#uniq(records)
    return ret
  catch /E117:/
    echoerr 'silo: select_distinct() depends misc-module > misc-module is not found.'
    return records
  endtry
endfunction
"}}}
function! s:Silo.get(where, ...) "{{{
  let fmt = get(a:, 1, [])
  let type = type(a:where)
  if empty(a:where)
    let idx = self.records==[] ? -1 : 0
  elseif type==s:TYPE_LIST
    let idx = index(self.records, self._get_refinepat_by_list(a:where))
  elseif type==s:TYPE_DICT
    let idx = match(self.records, self._get_refinepat_by_dict(a:where))
  else
    let idx = match(self.records, a:where)
  end
  if type(fmt)==s:TYPE_LIST
    if fmt==[]
      return idx==-1 ? [] : s:_listify(self.records[idx])
    end
    let fieldidxs = self._get_fieldidxs(fmt)
    return idx==-1 ? [] : s:_fmtmap_by_list(self.records[idx], fieldidxs)
  end
  let fieldidx = index(self.fields, fmt)
  if fieldidx==-1
    throw 'lim-silo: invalid format > '. fmt
  end
  return idx==-1 ? '' : s:_listify(self.records[idx])[fieldidx]
endfunction
"}}}
function! s:Silo.exclude(where, ...) "{{{
  let fmt = get(a:, 1, [])
  let type = type(a:where)
  if empty(a:where)
    let refineds = copy(self.records)
  elseif type==s:TYPE_LIST
    let pat = self._get_refinepat_by_list(a:where)
    let refineds = filter(copy(self.records), 'v:val !=# pat')
  elseif type==s:TYPE_DICT
    let pat = self._get_refinepat_by_dict(a:where)
    let refineds = filter(copy(self.records), 'v:val !~# pat')
  else
    let refineds = filter(copy(self.records), 'v:val !~# a:where')
  end
  let type = type(fmt)
  if type==s:TYPE_LIST
    return self._fmt_by_list(refineds, fmt)
  elseif type==s:TYPE_STR
    return self._fmt_by_str(refineds, fmt)
  end
  throw 'silo: invalid format > '. stirng(fmt)
endfunction
"}}}
function! s:Silo.nextkey(...) "{{{
  let field = get(a:, 1, self.key)
  let self._save_nextkeys = get(self, '_save_chgdtick', -1) != self.chgdtick ? {} : self._save_nextkeys
  let self._save_chgdtick = self.chgdtick
  if has_key(self._save_nextkeys, field)
    let self._save_nextkeys[field] = self._save_nextkeys[field] +1
    return self._save_nextkeys[field]
  elseif field!=''
    let self._save_nextkeys[field] = max(self.select({}, [field])) +1
    return self._save_nextkeys[field]
  end
  unlet self._save_chgdtick
  echoerr 'lim-silo: keyfield is not defined.'
endfunction
"}}}
function! s:Silo.set_nextkey(...) "{{{
  if !a:0 || a:0==1 && self.key==''
    echoerr 'lim-silo: 引数の数が足りません'
  end
  let val = a:000[-1]
  let field = a:0>1 ? a:1 : self.key
  let self._save_nextkeys = get(self, '_save_chgdtick', -1) != self.chgdtick ? {} : self._save_nextkeys
  let self._save_nextkeys[field] = val-1
endfunction
"}}}
function! s:Silo.commit() "{{{
  if !self.is_changed()
    return 1
  end
  if !isdirectory(self.dir)
    call mkdir(self.dir, 'p')
  end
  call writefile([s:_innerstrify(self.fields)] + self.records, self.path)
endfunction
"}}}
function! s:Silo.insert(rec) "{{{
  if type(get(a:rec, 0, []))!=s:TYPE_LIST
    return self._insert(a:rec)
  end
  let ret = 0
  for rec in a:rec
    let ret = self._insert(rec) || ret
  endfor
  return ret
endfunction
"}}}
function! s:Silo.update(where, rec) "{{{
  let targidxs = empty(a:where) ? range(self.fieldslen) : self._get_update_targidxs(a:where)
  let targlen = len(targidxs)
  if !targlen
    return -1
  end
  let rectype = type(a:rec)
  if rectype==s:TYPE_LIST
    return self._update_byreclist(a:rec, targlen, targidxs[0])
  elseif rectype==s:TYPE_DICT
    try
      call self._update_byrecdict(a:rec, targidxs)
    catch /invalid/
      echoerr v:exception
      return 2
    catch /duplicated/
      echoerr v:exception
      return 1
    endtry
  end
endfunction
"}}}
function! s:Silo.delete(where) "{{{
  let wheretype = type(a:where)
  if empty(a:where)
    let self.records = []
  elseif wheretype==s:TYPE_LIST
    let pat = self._get_refinepat_by_list(a:where)
    call filter(self.records, 'v:val !=# pat')
  elseif wheretype==s:TYPE_DICT
    let pat = self._get_refinepat_by_dict(a:where)
    call filter(self.records, 'v:val !~# pat')
  else
    call filter(self.records, 'v:val !~# a:where')
  end
  let self.chgdtick += 1
  return self
endfunction
"}}}
function! s:Silo.sort(...) "{{{
  if a:0
    call sort(self.records, a:1)
  else
    call sort(self.records)
  end
  return self
endfunction
"}}}
function! s:Silo.rearrange(destfields) "{{{
  if len(a:destfields) != self.fieldslen
    throw 'silo: invalid order > '. string(a:destfields)
  end
  let fieldidxs = self._get_fieldidxs(a:destfields)
  call map(self.records, 's:_inmap_rearrange(v:val, fieldidxs)')
  let self.fields = a:destfields
  return self
endfunction
"}}}
function! s:Silo.replace(field, src, dest) "{{{
endfunction
"}}}
function! s:Silo._insert(rec) "{{{
  if self.has(a:rec)
    return 1
  end
  if len(a:rec)!=self.fieldslen
    echoerr 'lim-silo : invalid insert >' a:rec
    return 2
  end
  call add(self.records, s:_innerstrify(a:rec))
  let self.chgdtick += 1
endfunction
"}}}
function! s:Silo._get_update_targidxs(where) "{{{
  let wheretype = type(a:where)
  let pat = wheretype==s:TYPE_LIST ? self._get_refinepat_by_list(a:where) : wheretype==s:TYPE_DICT ? self._get_refinepat_by_dict(a:where) : a:where
  let targidxs = []
  let idx = match(self.records, pat)
  while idx!=-1
    call add(targidxs, idx)
    let idx = match(self.records, pat, idx+1)
  endwhile
  return targidxs
endfunction
"}}}
function! s:Silo._update_byreclist(reclist, targlen, targidx) "{{{
  if a:targlen>1
    echoerr 'lim-silo: 条件が一意ではありません。'
    return 2
  elseif len(a:reclist)!=self.fieldslen
    echoerr 'lim-silo : fields'' len is invalid >' a:reclist
    return 2
  elseif self.has(a:reclist)
    echoerr 'lim-silo: 既に存在するレコードです。'
    return 1
  end
  let self.records[a:targidx] = s:_innerstrify(a:reclist)
  let self.chgdtick += 1
endfunction
"}}}
function! s:Silo._update_byrecdict(recdict, targidxs) "{{{
  let PAT = '.\{-}\%('.s:SEP.'\|$\)'
  let s:_sub_idx2dest = self._fieldkeydict_to_idxkeydict(a:recdict)
  let records = copy(self.records)
  for idx in a:targidxs
    let s:_sub_i = -1
    let records[idx] = substitute(records[idx], PAT, '\=s:_sub_4updatedict(submatch(0))', 'g')
  endfor
  unlet s:_sub_i s:_sub_idx2dest
  let seens = {}
  for record in records
    let str = ':'. record
    if has_key(seens, str)
      throw 'lim-silo: record is duplicated > '. record
    end
    let seens[str] = 1
  endfor
  let self.records = records
  let self.chgdtick += 1
endfunction
"}}}
function! s:Silo._fieldkeydict_to_idxkeydict(destdict) "{{{
  let ret = {}
  let lastidx = self.fieldslen-1
  for [field, dest] in items(a:destdict)
    let idx = index(self.fields, field)
    let ret[idx] = dest. (idx==lastidx ? '' : s:SEP)
  endfor
  if has_key(ret, '-1')
    throw 'lim-silo: invalid field > '. ret['-1']
  end
  return ret
endfunction
"}}}


function! lim#silo#create_silo(name, cols) "{{{
endfunction
"}}}
function! lim#silo#drop_silo(name) "{{{
endfunction
"}}}
function! lim#silo#rename_silo(name, to) "{{{
endfunction
"}}}
function! lim#silo#select(name, ...) "{{{
endfunction
"}}}
function! lim#silo#insert(name, values) "{{{
endfunction
"}}}


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
