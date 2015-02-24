# vim-easyreplace

Replace the substitute mode launched with the `c` flag (as in `:s/foo/bar/c`) with a solution that allows you to stay in normal mode and freely move / execute other commands while substituting.

![Sample pic](/../screenshots/1.gif?raw=true "easyreplace in action")


### Usage

Type `:s/foo/bar` like you normally would to substitute "foo" with "bar". Then press the initiate key set by this plugin (`ctrl-enter` if you run Vim with a GUI, otherwise `ctrl-g` for the command line and `ctrl-b` for the command window). You'll be put back to normal mode on the next match of `foo`. Now you can press `ctrl-n` in normal mode replace the closest `foo` with `bar` (and move to the next `foo` if possible). Or, unlike with `:s/foo/bar/c`, you can do any normal mode stuff you feel like doing. Use `n` to skip results between `c-n`s as you normally would.

You can prefix the `ctrl-n` command with a count to replace the next *n* matches at once.

Press `cpr` (mnemonic: change previous replace) in normal mode to make easyreplace always replace the latest search result with your latest substitution. This is also the default if you haven't started a replace with the initiate key yet, which means you can just type `:s/foo/bar<cr>` and start replacing foos with bars by hitting `ctrl-n`.


NOTE: If you are sure you'll never have multiple matches on one line, this built-in solution is probably better for you:

    nnoremap <c-n> :&&<cr>j0gn<esc>`<

 The above replaces all the matches on the current line with the result of your latest substitution. The difference to easyreplace is that easyreplace can handle multiple matches on a line one by one, and is immune to new searches and substitutions if you want it to be.


### Installation

Use your favorite plugin manager or just paste the files in your vim folder


### Configuration

`:let g:erepl_after_initiate = "zz"` (default '') Replace the `zz` to issue any normal mode commands to executue after you've entered a regex. NOTE: special characters (such as `<esc>`) and `"` must be escaped with `\`

`:let g:erepl_after_replace = "zz"` (default '') Same as g:erepl_after_initiate, except this gets executed after each substitution

`:let g:erepl_always_verymagic = 1` (default 0) Treat the target regex when executing a new substitution as if it started with `\v` if no other modifiers are given

**Available mappings:**

`<Plug>EasyReplaceInitiate` Map this to what you want to press in command line or cmdwindow to start the substitution.

example: `:cmap <c-x> <Plug>EasyReplaceInitiate`

`<Plug>EasyReplaceDo` Map this to what you want to press in normal mode to substitute the current match.

example: `:nmap <c-x> <Plug>EasyReplaceDo`

`<Plug>EasyReplaceBackwards` Map this to what you want to press in normal mode to substitute the current match and move to the preceding match.

example: `:nmap <c-x> <Plug>EasyReplaceBackwards`

`<Plug>EasyReplaceToggleUsePrevious` Make easyreplace always replace the latest search result with your latest substitution.

example: `:nmap cpr <Plug>EasyReplaceToggleUsePrevious`

`<Plug>EasyReplaceArea` Map this in visual mode to replace all your selected matches at once.

example: `:vmap <c-x> <Plug>EasyReplaceArea`


### Bugs

* Really long / complex searches might not work. The gn function used by this plugin tends to sometimes select only the first char on those, and these situations are where the plugin also fails.
* Searches containing only one char might not work. gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. gn might even skip these matches altogether.
* If your substitution contains lookbehinds you might unwantedly get new matches or lose old ones between substitutions. This happens when the text seen by the next lookbehind changes after a substitution. If this ever becomes a problem you'll just have to use a normal substitution with the `c` flag instead.
* Doesn't "bump up" search/cmd history items (if needed) after replaces, only after initializations.


### License

Published under the MIT License.
