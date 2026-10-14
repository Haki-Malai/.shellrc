" Managed by .shellrc: edit shared/.vimrc, then run shell/shared-sync.sh.
set nocompatible

" Four-space fallback; file-type plugins may select appropriate indentation.
set tabstop=4 shiftwidth=4 softtabstop=4 expandtab
set autoindent
filetype plugin indent on
syntax enable

" Make quick edits easier to navigate.
set number norelativenumber cursorline
set scrolloff=5
set ruler showcmd showmode

" Preview search matches; capitals make a search case-sensitive.
set incsearch hlsearch ignorecase smartcase
nnoremap <silent> <C-l> :nohlsearch<CR><C-l>

" Familiar Backspace behavior and command-line completion.
set backspace=indent,eol,start
set wildmenu wildmode=longest:full,full

" Preserve terminal text selection and avoid saving undo history to disk.
set mouse=
if has('persistent_undo')
  set noundofile
endif

" Gruvbox works offline from the bundled theme, with terminal-color fallback.
set background=dark
let g:gruvbox_contrast_dark = 'medium'
if has('termguicolors') && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  set termguicolors
endif
if !empty(globpath(&runtimepath, 'colors/gruvbox.vim'))
  colorscheme gruvbox
endif
