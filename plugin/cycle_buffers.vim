vim9script

var state = {
      winid: 0,
      idx: 0,
      buffers: [],
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
  state.buffers = buffers
  SetInitialIndex(buffers)
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
  if empty(state.buffers)
    return
  endif
  var count = len(state.buffers)
  state.idx = (state.idx + delta) % count
  if state.idx < 0
    state.idx += count
  endif
  UpdateLines()
enddef

def OpenSelected()
  if !IsDialogOpen()
    echohl WarningMsg
    echom 'cycle-buffers: Dialog is not open.'
    echohl None
    return
  endif
  if empty(state.buffers)
    CloseDialog()
    return
  endif
  var target = state.buffers[state.idx]
  CloseDialog()
  execute($'buffer {target.bufnr}')
enddef

def CycleFilter(id: number, key: string): bool
  if !IsDialogOpen()
    return false
  endif
  if key ==# "\<Esc>" || key ==# "\<C-[>" || key ==# "\<C-c>"
    CloseDialog()
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

