let s:suite = themis#suite('lim-silo')
let s:assert = themis#helper('assert')
call themis#helper('command').with(s:assert)
let s:funcs = lim#misc#get_sfuncs(expand('<sfile>:h:h').'/autoload/lim/silo.vim')

function! s:suite.before() "{{{
  let g:lim#silo#rootdir = expand('<sfile>:h').'/silo'
endfunction
"}}}

function! s:suite.__silotest__()
  let silotest = themis#suite('silotest')
  function! silotest.before() "{{{
    let self.silo = lim#silo#newSilo('test', ['id', 'name', 'group'], {'key': 'id'})
  endfunction
  "}}}

  function! silotest.is_changed() "{{{
    Assert False(self.silo.is_changed())
    call self.silo.insert([self.silo.nextkey(), 'aaa', 'A'])
    Assert True(self.silo.is_changed())
    call self.silo.delete({})
  endfunction
  "}}}
  function! silotest.nextkey() "{{{
    let nextkey = self.silo.nextkey()
    Assert Equals(nextkey, 1)
    call self.silo.insert([nextkey, 'aaa', 'A'])
    Assert Equals(self.silo.nextkey(), 2)
    call self.silo.set_nextkey(5)
    Assert Equals(self.silo.nextkey(), 5)
    Assert Equals(self.silo.nextkey(), 6)
    Assert Equals(self.silo.nextkey(), 7)
    call self.silo.set_nextkey(2)
  endfunction
  "}}}
  function! silotest.single_record() "{{{
    Assert Equals(self.silo.get({}), ['1', 'aaa', 'A'])
    Assert Equals(self.silo.select({}), [['1', 'aaa', 'A']])
    Assert Equals(self.silo.select({}, ['name', 'group']), [['aaa', 'A']])
    Assert Equals(self.silo.get({}, 'id'), '1')
  endfunction
  "}}}
  function! silotest.multi_records() "{{{
    call self.silo.insert([self.silo.nextkey(), 'bbb', 'A'])
    call self.silo.insert([[self.silo.nextkey(), 'ccc', 'B'], [self.silo.nextkey(), 'ddd', 'B']])
    Assert Equals(self.silo.select({'group': 'B'}, 'name'), ['ccc', 'ddd'])
    Assert Equals(self.silo.select({'group': 'A'}, ['name', 'id']), [['aaa', '1'], ['bbb', '2']])
    Assert Equals(self.silo.get({'name': 'ccc'}, ['id', 'group']), ['3', 'B'])
  endfunction
  "}}}
  function! silotest.select_grouped() "{{{
    Assert Equals(self.silo.select({}, ['id', 'name', 'group']), [['1', 'aaa', 'A'], ['2', 'bbb', 'A'], ['3', 'ccc', 'B'], ['4', 'ddd', 'B']])
    Assert Equals(self.silo.select_grouped({}, 'group', 'id', 'name'), [['A', [['1', ['aaa']], ['2', ['bbb']]]], ['B', [['3', ['ccc']], ['4', ['ddd']]]]])
  endfunction
  "}}}
  function! silotest.select_denial() "{{{
    Assert Equals(self.silo.select({'!id': '1'}), [['2', 'bbb', 'A'], ['3', 'ccc', 'B'], ['4', 'ddd', 'B']])
    Assert Equals(self.silo.select({'!id': '1', '!name': 'ccc'}), [['2', 'bbb', 'A'], ['4', 'ddd', 'B']])
    Assert Equals(self.silo.select({'!group': 'A'}), [['3', 'ccc', 'B'], ['4', 'ddd', 'B']])
    Assert Equals(self.silo.get({'!group': 'A', 'name': 'ddd'}), ['4', 'ddd', 'B'])
    Assert Equals(self.silo.select({'group': 'A', '!id': '2'}), [['1', 'aaa', 'A']])
  endfunction
  "}}}
  function! silotest.update() "{{{
    Assert Equals(self.silo.select({}, ['id', 'name', 'group']), [['1', 'aaa', 'A'], ['2', 'bbb', 'A'], ['3', 'ccc', 'B'], ['4', 'ddd', 'B']])
    call self.silo.update({'group': 'A'}, {'group': 'AAA'})
    Assert Equals(self.silo.select({'group': 'A'}), [])
    Assert Equals(self.silo.select({'group': 'AAA'}), [['1', 'aaa', 'AAA'], ['2', 'bbb', 'AAA']])
    call self.silo.update({'group': 'B'}, {'name': 'xxx'})
    Assert Equals(self.silo.select({'group': 'B'}, 'name'), ['xxx', 'xxx'])
    call self.silo.update({'id': '4'}, ['4', 'eee', 'C'])
    Assert Equals(self.silo.get({'id': 4}), ['4', 'eee', 'C'])
  endfunction
  "}}}
endfunction


function! s:suite.select_grouped() "{{{
  let silo = lim#silo#newSilo('test', ['group', 'color', 'name', 'sex'])
  call themis#func_alias({'silo': silo})
  call silo.insert([['A', 'red', 'aaa', 'female'], ['A', 'red', 'bbb', 'male'], ['A', 'blue', 'ccc', 'male'], ['A', 'blue', 'ddd', 'female'], ['B', 'red', 'eee', 'female'], ['B', 'red', 'fff', 'female'], ['B', 'blue', 'ggg', 'male'], ['B', 'blue', 'hhh', 'female']])

  Assert Equals(silo.select_grouped({}, 'group'), ['A', 'B'])

  Assert Equals(silo.select_grouped({}, 'group', ['color', 'name']), [['A', [['red', 'aaa'], ['red', 'bbb'], ['blue', 'ccc'], ['blue', 'ddd']]], ['B', [['red', 'eee'], ['red', 'fff'], ['blue', 'ggg'], ['blue', 'hhh']]]])

  Assert Equals(silo.select_grouped({}, 'group', 'color'), [['A', ['red', 'blue']], ['B', ['red', 'blue']]])

  Assert Equals(silo.select_grouped({}, ['group', 'color']), [['A', 'red'], ['A','blue'], ['B', 'red'], ['B', 'blue']])

  Assert Equals(silo.select_grouped({}, 'group', 'color', 'name'), [['A', [['red', ['aaa', 'bbb']], ['blue', ['ccc', 'ddd']]]], ['B', [['red', ['eee', 'fff']], ['blue', ['ggg', 'hhh']]]]])

  Assert Equals(silo.select_grouped({}, ['group', 'color'], 'name'), [['A', 'red', ['aaa', 'bbb']], ['A','blue', ['ccc', 'ddd']], ['B', 'red', ['eee', 'fff']], ['B', 'blue', ['ggg', 'hhh']]])

  Assert Equals(silo.select_grouped({}, ['sex', 'color'], 'name'), [['female', 'red', ['aaa', 'eee', 'fff']], ['male', 'red', ['bbb']], ['male', 'blue', ['ccc', 'ggg']], ['female', 'blue', ['ddd', 'hhh']]])

  Assert Equals(silo.select_grouped({}, 'group', ['sex', 'color'], 'name'),
    \ [['A', [['female', 'red', ['aaa']], ['male', 'red', ['bbb']], ['male', 'blue', ['ccc']], ['female', 'blue', ['ddd']]]], ['B', [['female', 'red', ['eee', 'fff']], ['male', 'blue', ['ggg']], ['female', 'blue', ['hhh']]]]]
    \ )

  Assert Equals(silo.select_grouped({}, ['group', 'sex'], ['color', 'name']),
    \ [['A', 'female', [['red', 'aaa'], ['blue', 'ddd']]], ['A', 'male', [['red', 'bbb'], ['blue', 'ccc']]], ['B', 'female', [['red', 'eee'], ['red', 'fff'], ['blue', 'hhh']]], ['B', 'male', [['blue', 'ggg']]]]
    \ )
endfunction
"}}}

