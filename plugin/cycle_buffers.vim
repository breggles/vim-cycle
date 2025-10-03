vim9script

var s:state = {
      winid: 0,
      idx: 0,
      buffers: [] as list<dict<any>>,
}

def s:is_dialog_open(): bool
  if s:state.winid == 0
    return false
  endif
  return popup_getpos(s:state.winid) != {}
enddef

def s:close_dialog()
  if s:is_dialog_open()
    popup_close(s:state.winid)
  endif
  s:state.winid = 0
  s:state.idx = 0
  s:state.buffers = []
enddef

def s:get_buffers(): list<dict<any>>
  var buffers = getbufinfo({ 'buflisted': 1 })
  if empty(buffers)
    return []
  endif
  buffers->sort((a, b) => b.lastused - a.lastused)
  return buffers
enddef

def s:display_name(buf: dict<any>): string
  if buf.name == ''
    return '[No Name]'
  endif
  return fnamemodify(buf.name, ':~:.')
enddef

def s:set_initial_index(buffers: list<dict<any>>)
  var alt = bufnr('#')
  if alt <= 0
    s:state.idx = 0
    return
  endif
  for idx in range(len(buffers))
    if buffers[idx].bufnr == alt
      s:state.idx = idx
      return
    endif
  endfor
  s:state.idx = 0
enddef

def s:build_lines(): list<string>
  var lines: list<string> = []
  var current = bufnr('%')
  var alternate = bufnr('#')
  for idx in range(len(s:state.buffers))
    var buf = s:state.buffers[idx]
    var selected = idx == s:state.idx
    var select_marker = selected ? '▸' : ' '
    var current_marker = buf.bufnr == current ? '*' : ' '
    var alt_marker = buf.bufnr == alternate ? '#' : ' '
    var modified_marker = buf.changed != 0 ? '+' : ' '
    var name = s:display_name(buf)
    lines->add(printf('%s %s%s%s [%d] %s', select_marker, current_marker, alt_marker, modified_marker, buf.bufnr, name))
  endfor
  return lines
enddef

def s:position_cursor()
  if !s:is_dialog_open()
    return
  endif
  var target = s:state.idx + 1
  win_execute(s:state.winid, printf('normal! %dG', target))
enddef

def s:update_lines()
  if !s:is_dialog_open()
    return
  endif
  popup_settext(s:state.winid, s:build_lines())
  s:position_cursor()
enddef

def s:open_dialog()
  var buffers = s:get_buffers()
  if empty(buffers)
    s:close_dialog()
    echohl WarningMsg
    echom 'cycle-buffers: No listed buffers to show.'
    echohl None
    return
  endif
  s:state.buffers = buffers
  s:set_initial_index(buffers)
  var content = s:build_lines()
  if s:is_dialog_open()
    popup_settext(s:state.winid, content)
  else
    var opts = {
          title: 'Buffer Cycle',
          padding: [0, 1, 0, 1],
          border: [1, 1, 1, 1],
          borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
          minwidth: 40,
          pos: 'center',
          scrollbar: 0,
          cursorline: true,
          wrap: false,
          zindex: 300,
        }
    s:state.winid = popup_create(content, opts)
  endif
  s:position_cursor()
enddef

def s:cycle(delta: number)
  if !s:is_dialog_open()
    echohl WarningMsg
    echom 'cycle-buffers: Dialog is not open.'
    echohl None
    return
  endif
  if empty(s:state.buffers)
    return
  endif
  var count = len(s:state.buffers)
  s:state.idx = (s:state.idx + delta) % count
  if s:state.idx < 0
    s:state.idx += count
  endif
  s:update_lines()
enddef

def s:open_selected()
  if !s:is_dialog_open()
    echohl WarningMsg
    echom 'cycle-buffers: Dialog is not open.'
    echohl None
    return
  endif
  if empty(s:state.buffers)
    s:close_dialog()
    return
  endif
  var target = s:state.buffers[s:state.idx]
  s:close_dialog()
  execute($'buffer {target.bufnr}')
enddef

command! -nargs=0 CycleBufferDialog vim9cmd s:open_dialog()
command! -nargs=0 CycleBufferNext vim9cmd s:cycle(1)
command! -nargs=0 CycleBufferPrev vim9cmd s:cycle(-1)
command! -nargs=0 CycleBufferOpen vim9cmd s:open_selected()

nnoremap <silent> <Plug>(CycleBufferDialog) <Cmd>CycleBufferDialog<CR>
nnoremap <silent> <Plug>(CycleBufferNext) <Cmd>CycleBufferNext<CR>
nnoremap <silent> <Plug>(CycleBufferPrev) <Cmd>CycleBufferPrev<CR>
nnoremap <silent> <Plug>(CycleBufferOpen) <Cmd>CycleBufferOpen<CR>

if !get(g:, 'cycle_buffer_no_default_maps', 0)
  if maparg('<leader>bb', 'n') == ''
    nnoremap <silent> <leader>bb <Plug>(CycleBufferDialog)
  endif
  if maparg('<leader>bn', 'n') == ''
    nnoremap <silent> <leader>bn <Plug>(CycleBufferNext)
  endif
  if maparg('<leader>bp', 'n') == ''
    nnoremap <silent> <leader>bp <Plug>(CycleBufferPrev)
  endif
  if maparg('<leader>bo', 'n') == ''
    nnoremap <silent> <leader>bo <Plug>(CycleBufferOpen)
  endif
endif

