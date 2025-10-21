vim9script

var state = {
      winid: 0,
      idx: 0,
      buffers: [],
      preview: 0,
      targetwin: 0,
}

def IsDialogOpen(): bool
  if state.winid == 0
    return false
  endif
  return popup_getpos(state.winid) != {}
enddef

def CloseDialog()
  if IsDialogOpen()
    popup_close(state.winid)
  endif
  state.winid = 0
  state.idx = 0
  state.buffers = []
  state.targetwin = 0
enddef

def CancelDialog()
  var original = state.buffers[0].bufnr
  var win = state.targetwin
  CloseDialog()
  if win > 0 && winbufnr(win) != -1 && winbufnr(win) != original
    win_execute(win, printf('buffer %d', original))
  endif
enddef

def GetBuffers(): list<dict<any>>
  var buffers = getbufinfo({ 'buflisted': 1 })
  if empty(buffers)
    return []
  endif
  buffers->sort((a, b) => b.lastused - a.lastused)
  return buffers
enddef

def DisplayName(buf: dict<any>): string
  if buf.name == ''
    return '[No Name]'
  endif
  return fnamemodify(buf.name, ':~:.')
enddef

def SetInitialIndex(buffers: list<dict<any>>)
  var alt = bufnr('#')
  if alt > 0
    for idx in range(len(buffers))
      if buffers[idx].bufnr == alt
        state.idx = idx
        return
      endif
    endfor
  endif
  state.idx = len(buffers) > 1 ? 1 : 0
enddef

def EnsurePreviewBuffer()
  if state.preview == 0 || !bufexists(state.preview)
    state.preview = bufadd('Buffer Ring Preview')
  endif
  bufload(state.preview)
  setbufvar(state.preview, '&buflisted', 0)
  setbufvar(state.preview, '&buftype', 'nofile')
  setbufvar(state.preview, '&swapfile', 0)
  setbufvar(state.preview, '&bufhidden', 'hide')
  setbufvar(state.preview, '&undolevels', -1)
  setbufvar(state.preview, '&modifiable', 0)
  setbufvar(state.preview, '&readonly', 1)
enddef

def ShowCurrentSelection()
  if state.targetwin == 0
    return
  endif
  EnsurePreviewBuffer()
  var win = state.targetwin
  if win > 0 && winbufnr(win) != state.preview
    win_execute(win, printf('noautocmd buffer %d', state.preview))
  endif
  var target = state.buffers[state.idx]
  bufload(target.bufnr)
  var lines = getbufline(target.bufnr, 1, '$')
  if empty(lines)
    lines = ['']
  endif
  setbufvar(state.preview, '&modifiable', 1)
  setbufvar(state.preview, '&readonly', 0)
  if !empty(getbufline(state.preview, 1, '$'))
    deletebufline(state.preview, 1, '$')
  endif
  setbufline(state.preview, 1, lines)
  setbufvar(state.preview, '&modified', 0)
  setbufvar(state.preview, '&modifiable', 0)
  setbufvar(state.preview, '&readonly', 1)
  setbufvar(state.preview, '&filetype', getbufvar(target.bufnr, '&filetype'))
  var syntax = getbufvar(target.bufnr, '&syntax')
  if type(syntax) == v:t_string
    setbufvar(state.preview, '&syntax', syntax)
  endif
  var lnum = has_key(target, 'lnum') && target.lnum > 0 ? target.lnum : 1
  var col = has_key(target, 'col') && target.col > 0 ? target.col : 1
  win_execute(state.targetwin, printf('call cursor(%d, %d)', lnum, col))
enddef

def BuildLines(): list<string>
  var lines: list<string> = []
  var current = bufnr('%')
  for buf in state.buffers
    var modified_marker = buf.changed != 0 ? '+' : ' '
    var name = DisplayName(buf)
    lines->add(printf('%s [%d] %s', modified_marker, buf.bufnr, name))
  endfor
  return lines
enddef

def PositionCursor()
  if !IsDialogOpen()
    return
  endif
  var target = state.idx + 1
  win_execute(state.winid, printf('normal! %dG', target))
enddef

def UpdateLines()
  if !IsDialogOpen()
    return
  endif
  popup_settext(state.winid, BuildLines())
  PositionCursor()
enddef

def OpenDialog()
  var buffers = GetBuffers()
  if empty(buffers)
    CloseDialog()
    echohl WarningMsg
    echom 'cycle-buffers: No listed buffers to show.'
    echohl None
    return
  endif
  state.targetwin = win_getid()
  state.buffers = buffers
  SetInitialIndex(buffers)
  EnsurePreviewBuffer()
  if state.targetwin > 0 && bufexists(state.preview)
    if winbufnr(state.targetwin) != state.preview
      win_execute(state.targetwin, printf('noautocmd buffer %d', state.preview))
    endif
  endif
  ShowCurrentSelection()
  var content = BuildLines()
  if IsDialogOpen()
    popup_settext(state.winid, content)
  else
    var opts = {
          title: '──Buffer Ring',
          padding: [0, 1, 0, 1],
          border: [1, 1, 1, 1],
          borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
          minwidth: 40,
          pos: 'center',
          scrollbar: 0,
          cursorline: true,
          wrap: false,
          zindex: 300,
          mapping: 0,
          enter: true,
          filter: CycleFilter,
        }
    state.winid = popup_create(content, opts)
  endif
  PositionCursor()
enddef

def Cycle(delta: number)
  if !IsDialogOpen()
    echohl WarningMsg
    echom 'cycle-buffers: Dialog is not open.'
    echohl None
    return
  endif
  var count = len(state.buffers)
  state.idx = (state.idx + delta) % count
  if state.idx < 0
    state.idx += count
  endif
  ShowCurrentSelection()
  UpdateLines()
enddef

def OpenSelected()
  if !IsDialogOpen()
    echohl WarningMsg
    echom 'cycle-buffers: Dialog is not open.'
    echohl None
    return
  endif
  var target = state.buffers[state.idx]
  var win = state.targetwin
  CloseDialog()
  if win > 0 && winbufnr(win) != -1 && winbufnr(win) != target.bufnr
    win_execute(win, printf('buffer %d', target.bufnr))
  endif
enddef

def CycleFilter(id: number, key: string): bool
  if !IsDialogOpen()
    return false
  endif
  if key ==# "\<Esc>" || key ==# "\<C-[>" || key ==# "\<C-c>"
    CancelDialog()
    return true
  endif
  if key ==# "\<CR>" || key ==# "\<Space>"
    OpenSelected()
    return true
  endif
  if key ==# "\<Down>" || key ==# "\<C-n>" || key ==# "\<Tab>" || key ==# "\<C-Tab>" || key ==# 'j'
    Cycle(1)
    return true
  endif
  if key ==# "\<Up>" || key ==# "\<C-p>" || key ==# "\<S-Tab>" || key ==# "\<C-S-Tab>" || key ==# 'k'
    Cycle(-1)
    return true
  endif
  return true
enddef

command! -nargs=0 CycleBufferDialog vim9cmd OpenDialog()
command! -nargs=0 CycleBufferNext vim9cmd Cycle(1)
command! -nargs=0 CycleBufferPrev vim9cmd Cycle(-1)
command! -nargs=0 CycleBufferOpen vim9cmd OpenSelected()

nnoremap <silent> <Plug>(CycleBufferDialog) <Cmd>CycleBufferDialog<CR>
nnoremap <silent> <Plug>(CycleBufferNext) <Cmd>CycleBufferNext<CR>
nnoremap <silent> <Plug>(CycleBufferPrev) <Cmd>CycleBufferPrev<CR>
nnoremap <silent> <Plug>(CycleBufferOpen) <Cmd>CycleBufferOpen<CR>

if !get(g:, 'cycle_buffer_no_default_maps', 0)
  if maparg('<C-Tab>', 'n') == ''
    nnoremap <silent> <C-Tab> <Plug>(CycleBufferDialog)
  endif
endif

