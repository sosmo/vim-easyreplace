# vim-easyreplace

Replace the substitute mode launched with the `c` flag (as in `:s/foo/bar/c`) with a solution that allows you to stay in normal mode and freely move / execute other commands while substituting.


### Usage

Type `:s/foo/bar` like you normally would to substitute "foo" with "bar". Then press the initiate key set by this plugin (`ctrl-enter` if you run Vim with a GUI, otherwise `ctrl-g` for the command line and `ctrl-b` for the command window). You'll be put back to normal mode on the next match of `foo`. Now you can press `ctrl-n` in normal mode replace the closest `foo` with `bar` (and move to the next `foo` if possible). Or, unlike with `:s/foo/bar/c`, you can do any normal mode stuff you feel like doing. Use `n` to skip results between `c-n`s as you normally would.

You can prefix the `ctrl-n` command with a count to replace the next *n* matches at once.

Press `cpr` (mnemonic: change previous replace) in normal mode to make easyreplace always replace the latest search result with your latest substitution.


NOTE: If you are sure you'll never have multiple matches on one line (or you don't mind always replacing all of them at the same time), this built-in solution is probably better for you:

    nnoremap <c-n> :&&<cr>j0gn<esc>`<

The built-in solution doesn't move to the next match automatically if you search for something else after starting the substitution. If you consider this a problem you may still want to use this plugin despite the added complexity and the couple of quirks


### Installation

Use your favorite plugin manager, or just paste the files in your vim folder


### Configuration

`:let g:erepl_after_initiate = "zz"` Replace the "zz" to issue any normal mode commands to executue after you've entered a regex. NOTE: special characters (such as "<esc>") and """ must be escaped with "\"

`:let g:erepl_after_replace = "zz"` Same as g:erepl_after_initiate, except this gets executed after each substitution

**Available mappings:**

`<Plug>EasyReplaceInitiate` Map this to what you want to press in command line or cmdwindow to start the substitution.

example: `:cmap <c-x> <Plug>EasyReplaceInitiate`

`<Plug>EasyReplaceDo` Map this to what you want to press in normal mode to substitute the current match.

example: `:nmap <c-x> <Plug>EasyReplaceDo`

`<Plug>EasyReplaceToggleUsePrevious` Make easyreplace always replace the latest search result with your latest substitution.

example: `:nmap cpr <Plug>EasyReplaceToggleUsePrevious`


### Bugs

* Really long / complex searches might not work. The gn function used by this plugin tends to sometimes select only the first char on those, and these situations are where the plugin also fails.
* Searches containing only one char might not work. gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. gn might even skip these matches altogether.
* \zs and \ze don't work in the search pattern (way too big of a hassle to get them right). \@<= and \@= still work normally so they should offer a rather painless workaround.
* Doesn't "bump up" search/cmd history items (if needed) after replaces, only after initializations.


### License

Published under the MIT License.
