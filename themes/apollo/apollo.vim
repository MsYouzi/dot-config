" Apollo colorscheme for Vim
" Catppuccin Mocha base + deeper crust canvas (#11111b).
" Install: cp apollo.vim ~/.vim/colors/  (or symlink)
" Use:     :colorscheme apollo

hi clear
if exists('syntax_on') | syntax reset | endif
let g:colors_name = 'apollo'
set background=dark

" Palette
let s:bg     = '#11111b'
let s:bg1    = '#181825'
let s:bg2    = '#313244'
let s:fg     = '#cdd6f4'
let s:fg_dim = '#6c7086'
let s:fg2    = '#bac2de'
let s:red    = '#f38ba8'
let s:green  = '#a6e3a1'
let s:yellow = '#f9e2af'
let s:blue   = '#89b4fa'
let s:purple = '#f5c2e7'
let s:aqua   = '#94e2d5'
let s:beige  = '#bac2de'
let s:bred   = '#f38ba8'
let s:bgreen = '#a6e3a1'
let s:byellow= '#f9e2af'
let s:bblue  = '#89b4fa'
let s:bpurple= '#cba6f7'
let s:baqua  = '#94e2d5'

function! s:hi(group, fg, bg, attr) abort
  let l:cmd = 'hi ' . a:group
  if a:fg !=# '' | let l:cmd .= ' guifg=' . a:fg | endif
  if a:bg !=# '' | let l:cmd .= ' guibg=' . a:bg | endif
  if a:attr !=# '' | let l:cmd .= ' gui=' . a:attr . ' cterm=' . a:attr | endif
  execute l:cmd
endfunction

call s:hi('Normal',       s:fg,     s:bg,  '')
call s:hi('NormalNC',     s:fg,     s:bg,  '')
call s:hi('CursorLine',   '',       s:bg1, '')
call s:hi('CursorLineNr', s:byellow,s:bg1, 'bold')
call s:hi('LineNr',       s:fg_dim, s:bg,  '')
call s:hi('SignColumn',   '',       s:bg,  '')
call s:hi('VertSplit',    s:bg2,    s:bg,  '')
call s:hi('WinSeparator', s:bg2,    s:bg,  '')
call s:hi('StatusLine',   s:fg,     s:bg2, 'none')
call s:hi('StatusLineNC', s:fg_dim, s:bg1, 'none')
call s:hi('Pmenu',        s:fg,     s:bg1, '')
call s:hi('PmenuSel',     s:bg,     s:byellow, 'bold')
call s:hi('Visual',       '',       s:bg2, '')
call s:hi('Search',       s:bg,     s:byellow, '')
call s:hi('IncSearch',    s:bg,     s:bred,    '')
call s:hi('MatchParen',   s:byellow,s:bg2, 'bold')
call s:hi('Folded',       s:fg_dim, s:bg1, 'italic')
call s:hi('NonText',      s:bg2,    '',    '')
call s:hi('SpecialKey',   s:bg2,    '',    '')
call s:hi('Directory',    s:bblue,  '',    '')
call s:hi('Title',        s:byellow,'',    'bold')
call s:hi('ColorColumn',  '',       s:bg1, '')

" Syntax
call s:hi('Comment',      s:fg_dim, '',    'italic')
call s:hi('Constant',     s:bpurple,'',    '')
call s:hi('String',       s:bgreen, '',    '')
call s:hi('Character',    s:bpurple,'',    '')
call s:hi('Number',       s:bpurple,'',    '')
call s:hi('Boolean',      s:bpurple,'',    '')
call s:hi('Identifier',   s:bblue,  '',    '')
call s:hi('Function',     s:byellow,'',    '')
call s:hi('Statement',    s:bred,   '',    '')
call s:hi('Keyword',      s:bred,   '',    '')
call s:hi('Conditional',  s:bred,   '',    '')
call s:hi('Repeat',       s:bred,   '',    '')
call s:hi('Operator',     s:fg2,    '',    '')
call s:hi('PreProc',      s:baqua,  '',    '')
call s:hi('Include',      s:baqua,  '',    '')
call s:hi('Define',       s:baqua,  '',    '')
call s:hi('Macro',        s:baqua,  '',    '')
call s:hi('Type',         s:byellow,'',    '')
call s:hi('StorageClass', s:byellow,'',    '')
call s:hi('Structure',    s:byellow,'',    '')
call s:hi('Special',      s:bpurple,'',    '')
call s:hi('Delimiter',    s:fg2,    '',    '')
call s:hi('Todo',         s:bg,     s:byellow, 'bold')
call s:hi('Error',        s:bred,   '',    'bold')
call s:hi('WarningMsg',   s:byellow,'',    '')
call s:hi('ErrorMsg',     s:bred,   '',    'bold')

" Diff
call s:hi('DiffAdd',      s:bgreen, s:bg1, '')
call s:hi('DiffChange',   s:byellow,s:bg1, '')
call s:hi('DiffDelete',   s:bred,   s:bg1, '')
call s:hi('DiffText',     s:bg,     s:byellow, 'bold')

" Diagnostics (Neovim falls back here too)
call s:hi('DiagnosticError', s:bred,    '', '')
call s:hi('DiagnosticWarn',  s:byellow, '', '')
call s:hi('DiagnosticInfo',  s:bblue,   '', '')
call s:hi('DiagnosticHint',  s:baqua,   '', '')
