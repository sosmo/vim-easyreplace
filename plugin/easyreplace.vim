"# vim-easyreplace
"
"Replace the substitute mode launched with the `c` flag (as in `:s/foo/bar/c`) with a solution that allows you to stay in normal mode and freely move / execute other commands while substituting.
"
"
"### Usage
"
"Type `:s/foo/bar` like you normally would to substitute "foo" with "bar". Then press the initiate key set by this plugin (`ctrl-enter` if you run Vim with a GUI, otherwise `ctrl-g` for the command line and `ctrl-b` for the command window). You'll be put back to normal mode on the next match. Then press `ctrl-n` to replace the match in normal mode, or press `n` to skip results as you normally would.
"
"Press `cpr` (mnemonic: toggle previous replace) in normal mode to make easyreplace always replace the latest search result with your latest substitution.
"
"
"### Use cases
"
"1. You can't create a regex that only matches wanted items, or aren't sure there won't be any unwanted matches
"2. You don't know beforehand the exact area where you want to substitute (so you can't use visual mode to limit the area of the operation) or just don't want to select it with visual mode (if it's big for example)
"3. You want to keep quick substitutions simple and graphic
"
"NOTE: If you are sure you'll never have multiple matches on one line (or you don't mind always replacing all of them at the same time), this built-in solution is probably better for you:
"
"    nnoremap <c-n> <esc>:&&<cr>jgn<esc>`<
"
"The built-in solution doesn't move to the next match automatically if you search for something else after starting the substitution. If you consider this a problem you may still want to use this plugin despite the added complexity and the couple of quirks
"
"
"### Installation
"
"Use your favorite plugin manager, or just paste the files in your vim folder
"
"
"### Configuration
"
":let g:erepl_after_initiate = "zz"
"    Replace the "zz" to issue any normal mode commands to executue after you've entered a regex. NOTE: special characters (such as "<esc>") and """ must be escaped with "\"
"`:let g:erepl_after_replace = "zz"`
"    Same as g:erepl_after_initiate, except this gets executed after each substitution
"
"*Available mappings:*
"`<Plug>EasyReplaceInitiate`
"    Map this to what you want to press in command line or cmdwindow to start the substitution.
"    example: `:cmap <c-x> <Plug>EasyReplaceInitiate`
"`<Plug>EasyReplaceDo`
"    Map this to what you want to press in normal mode to substitute the current match.
"    example: `:nmap <c-x> <Plug>EasyReplaceDo`
"`<Plug>EasyReplaceToggleUsePrevious`
"    Make easyreplace always replace the latest search result with your latest substitution.
"    example: `:nmap cpr <Plug>EasyReplaceToggleUsePrevious`
"
"
"### Bugs
"
"* Really long / complex searches might not work. The gn function used by this plugin tends to sometimes select only the first char on those, and these situations are where the plugin also fails.
"* Searches containing only one char might not work. gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. gn might even skip these matches altogether.
"* \zs and \ze don't work in the search pattern (way too big of a hassle to get them right). \@<= and \@= still work normally so they should offer a rather painless workaround.
"* Jump history could be left tidier, currently there's at least one extra mark left with each substitution.
"* Doesn't "bump up" search/cmd history items (if needed) after replaces, only after initiatiolizations.
"
"
"### License
"
"Published under the MIT License.




" define user custom operations to run after each easyreplace initiation or replace operation. special characters (such as "<esc>") and """ must be escaped with "\"
if !exists("g:erepl_after_initiate")
	let g:erepl_after_initiate = ""
endif
if !exists("g:erepl_after_replace")
	let g:erepl_after_replace = ""
endif


" a bit ugly, but has to be mapped like this to escape cmd and record typed command to cmd history
inoremap <silent> <Plug>EasyReplaceInitiate <c-c><c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>
nnoremap <silent> <Plug>EasyReplaceInitiate <c-c><c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>
cnoremap <silent> <Plug>EasyReplaceInitiate <c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>

nnoremap <silent> <Plug>EasyReplaceDo <esc>:<c-u>call easyreplace#EasyReplaceDo()<cr>

nnoremap <silent> <Plug>EasyReplaceToggleUsePrevious <esc>:<c-u>call easyreplace#EasyReplaceToggleUsePrevious()<cr>


" <c-cr> doesn't work for most terminals.
" for terminals by default use <c-b> to initiate from insert mode (cmdwindow) and <c-g> to initiate from cmdline
if has("gui_running")
	if !hasmapto('<Plug>EasyReplaceInitiate') && maparg('<c-n>', 'i') ==# ''
		imap <c-cr> <Plug>EasyReplaceInitiate
	endif
	if !hasmapto('<Plug>EasyReplaceInitiate') && maparg('<c-n>', 'n') ==# ''
		nmap <c-cr> <Plug>EasyReplaceInitiate
	endif
	if !hasmapto('<Plug>EasyReplaceInitiate') && maparg('<c-n>', 'c') ==# ''
		cmap <c-cr> <Plug>EasyReplaceInitiate
	endif
else
	if !hasmapto('<Plug>EasyReplaceInitiate') && maparg('<c-n>', 'i') ==# ''
		imap <c-b> <Plug>EasyReplaceInitiate
	endif
	if !hasmapto('<Plug>EasyReplaceInitiate') && maparg('<c-n>', 'c') ==# ''
		cmap <c-g> <Plug>EasyReplaceInitiate
	endif
endif

if !hasmapto('<Plug>EasyReplaceDo') && maparg('<c-n>', 'n') ==# ''
	nmap <c-n> <Plug>EasyReplaceDo
endif

" mnemonic: change previous replace
if !hasmapto('<Plug>EasyReplaceToggleUsePrevious') && maparg('cpr', 'n') ==# ''
	nmap cpr <Plug>EasyReplaceToggleUsePrevious
endif
