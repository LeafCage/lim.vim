if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:lim#silo#rootdir = get(g:, 'lim#silo#rootdir', '~/.config/silo')
let s:SEP = "\<C-k>\<Tab>"
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})
let s:TYPE_STR = type('')

"Misc:
function! s:_listify(record) "{{{
  return split(a:record, s:SEP)
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
  return join(map(a:fieldidxs, 'rec[(v:val)]'), s:SEP)
endfunction
"}}}
function! s:_inmap_chk_fmt(record, fieldidxs) "{{{
  let rec = s:_listify(a:record)
  return join(map(a:fieldidxs, 'v:val==-1 ? "" : rec[(v:val)]'), s:SEP)
endfunction
"}}}


"=============================================================================
"Public:
let s:Silo = {}
function! lim#silo#newSilo(name, fields) "{{{
  let obj = copy(s:Silo)
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
    if obj._chk_fmt(oldformat)
      return {}
    end
  catch /E684:/
  endtry
  let obj.save_records = copy(obj.records)
  return obj
endfunction
"}}}
function! s:Silo._chk_fmt(oldformat) "{{{
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
  return join(a:listwhere, s:SEP)
endfunction
"}}}
function! s:Silo._get_refinepat_by_dict(dictwhere) "{{{
  let order = {}
  for [field, val] in items(a:dictwhere)
    let idx = index(self.fields, field)
    if idx==-1
      echoerr 'silo: invalid field name >' field
    elseif type(val)!=s:TYPE_STR
      throw 'silo: invalid condition > '. string(a:dictwhere)
    end
    let order[idx] = val
  endfor
  let i = 0
  let pat = '^'
  while i < self.fieldslen-1
    let pat .= '\%('. get(order, i, '\m.\{-}'). '\)'. s:SEP
    let i += 1
  endwhile
  let pat .= '\%('. get(order, i, '\m.\{-}'). '\)'. '$'
  return pat
endfunction
"}}}
function! s:Silo._get_fieldidxs(fmt) "{{{
  let fieldidxs = map(copy(a:fmt), 'index(self.fields, v:val)')
  if index(fieldidxs, -1)!=-1
    throw 'silo: invalid format > '. string(a:fmt)
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
  if a:fmt==''
    return a:records
  end
  let fieldsstr = substitute(string(self.fields), "'", '', 'g')
  echom fieldsstr
  return map(a:records, 's:_fmtmap_by_str(v:val, fieldsstr, a:fmt)')
endfunction
"}}}
function! s:Silo.is_changed() "{{{
  return self.records !=# self.save_records
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
    let ret = lim#misc#uniqify(records)
    return ret
  catch /E117:/
    echoerr 'silo: select_distinct() depends misc-module > misc-module is not found.'
    return records
  endtry
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
function! s:Silo.create_nextkey(field) "{{{
  return max(self.select({}, [a:field])) +1
endfunction
"}}}
function! s:Silo.commit() "{{{
  if !self.is_changed()
    return
  end
  if !isdirectory(self.dir)
    call mkdir(self.dir, 'p')
  end
  call writefile([join(self.fields, s:SEP)] + self.records, self.path)
endfunction
"}}}
function! s:Silo.insert(rec) "{{{
  if type(get(a:rec, 0, []))==s:TYPE_STR
    return self._insert(a:rec)
  end
  for rec in a:rec
    call self._insert(rec)
  endfor
  return self
endfunction
"}}}
function! s:Silo.delete(where) "{{{
  let type = type(a:where)
  if empty(a:where)
    let self.records = []
  elseif type==s:TYPE_LIST
    let pat = self._get_refinepat_by_list(a:where)
    call filter(self.records, 'v:val !=# pat')
  elseif type==s:TYPE_DICT
    let pat = self._get_refinepat_by_dict(a:where)
    call filter(self.records, 'v:val !~# pat')
  else
    call filter(self.records, 'v:val !~# a:where')
  end
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
    return self
  end
  if len(a:rec)!=self.fieldslen
    echoerr 'silo : invalid insert >' a:rec
    return self
  end
  call add(self.records, join(a:rec, s:SEP))
  return self
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
