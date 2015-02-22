"# vim-easyreplace
"
"Replace the substitute mode launched with the `c` flag (as in `:s/foo/bar/c`) with a solution that allows you to stay in normal mode and freely move / execute other commands while substituting.
"
"
"### Usage
"
"Type `:s/foo/bar` like you normally would to substitute "foo" with "bar". Then press the initiate key set by this plugin (`ctrl-enter` if you run Vim with a GUI, otherwise `ctrl-g` for the command line and `ctrl-b` for the command window). You'll be put back to normal mode on the next match of `foo`. Now you can press `ctrl-n` in normal mode replace the closest `foo` with `bar` (and move to the next `foo` if possible). Or, unlike with `:s/foo/bar/c`, you can do any normal mode stuff you feel like doing. Use `n` to skip results between `c-n`s as you normally would.
"
"You can prefix the `ctrl-n` command with a count to replace the next *n* matches at once.
"
"Press `cpr` (mnemonic: change previous replace) in normal mode to make easyreplace always replace the latest search result with your latest substitution. This is also the default if you haven't started a replace with the initiate key yet, which means you can just type `:s/foo/bar<cr>` and start replacing foos with bars by hitting `ctrl-n`.
"
"
"NOTE: If you are sure you'll never have multiple matches on one line, this built-in solution is probably better for you:
"
"    nnoremap <c-n> :&&<cr>j0gn<esc>`<
"
" The above replaces all the matches on the current line with the result of your latest substitution. The difference to EasyReplace is that the plugin can handle multiple matches on a line one by one, and is immune to new searches and substitutions if you want it to be.
"
"
"### Installation
"
"Use your favorite plugin manager or just paste the files in your vim folder
"
"
"### Configuration
"
"`:let g:erepl_after_initiate = "zz"` Replace the "zz" to issue any normal mode commands to executue after you've entered a regex. NOTE: special characters (such as "<esc>") and """ must be escaped with "\"
"
"`:let g:erepl_after_replace = "zz"` Same as g:erepl_after_initiate, except this gets executed after each substitution
"
"**Available mappings:**
"
"`<Plug>EasyReplaceInitiate` Map this to what you want to press in command line or cmdwindow to start the substitution.
"
"example: `:cmap <c-x> <Plug>EasyReplaceInitiate`
"
"`<Plug>EasyReplaceDo` Map this to what you want to press in normal mode to substitute the current match.
"
"example: `:nmap <c-x> <Plug>EasyReplaceDo`
"
"`<Plug>EasyReplaceToggleUsePrevious` Make easyreplace always replace the latest search result with your latest substitution.
"
"example: `:nmap cpr <Plug>EasyReplaceToggleUsePrevious`
"
"
"### Bugs
"
"* Really long / complex searches might not work. The gn function used by this plugin tends to sometimes select only the first char on those, and these situations are where the plugin also fails.
"* Searches containing only one char might not work. gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. gn might even skip these matches altogether.
"* Doesn't "bump up" search/cmd history items (if needed) after replaces, only after initializations.
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
if !exists("g:erepl_always_verymagic")
	let g:erepl_always_verymagic = 0
endif


" a bit ugly, but has to be mapped like this to escape cmd and record typed command to cmd history
inoremap <silent> <Plug>EasyReplaceInitiate <c-c><c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>
nnoremap <silent> <Plug>EasyReplaceInitiate <c-c><c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>
cnoremap <silent> <Plug>EasyReplaceInitiate <c-c>:call easyreplace#EasyReplaceInitiate(histget(":", -1))<cr>

nnoremap <silent> <Plug>EasyReplaceDo :<c-u>call easyreplace#EasyReplaceDo()<cr>

nnoremap <silent> <Plug>EasyReplaceToggleUsePrevious :<c-u>call easyreplace#EasyReplaceToggleUsePrevious()<cr>


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
