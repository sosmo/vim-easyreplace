let s:use_prev = 0
let s:sep = "/"
let s:search_str = ""
let s:replace_str = ""
let s:flags = ""
let s:end_paren = "\\)"
" last position where the cursor left off after the substitution operation
let s:next_pos = [0, 0, 0, 0]


fun! s:DefineFlags(flags_string)
	let s:flags = a:flags_string
	" remove possible "c" flag
	let s:flags = substitute(s:flags, '\Cc', '', "g")
	" conform to possible "I"/"i" flag
	if match(s:flags, '\CI') != -1
		let s:search_str .= "\\C"
	endif
	if match(s:flags, '\Ci') != -1
		let s:search_str .= "\\c"
	endif
	" add e flag to suppress errors
	let s:flags .= 'e'
endfun

fun! s:MatchBackwards(str, match)
	" note that multi-byte chars make this too big
	let i = strlen(a:str) - 1
	let found = -1
	while i >= 0 && found < 0
		let found = match(a:str, a:match, i)
		let i -= 1
	endwhile
	return found
endf

fun! s:IsVeryMagic(search_str)
	let magic = ""
	" get the last magic operator
	let magic_i = s:MatchBackwards(a:search_str, '\C\v\\@<!(\\\\)*\zs\\(v|m|M|V)')
	if magic_i >= 0
		let magic = strpart(a:search_str, magic_i, 2)
	endif
	"" slow regex
	"let magic = matchstr(s:search_str, '\v\C(\\@<!(\\\\)*\zs\\(v|m|M|V))@<!.*\\@<!(\\\\)*\zs\\(v|m|M|V)')
	if magic ==# '\v'
		return 1
	endif
	return 0
endfun

fun! s:SubStrCount(str, match, str_len)
	let found = 0
	let i = 0
	while i < a:str_len && i >= 0
		let i = match(a:str, a:match, i)
		if i >= 0
			let found += 1
			let i += 1
		endif
	endwhile
	return found
endfun

fun! s:CountChars(start, end)
	let line = a:start
	let chars = 0
	while line <= a:end
		let chars += strlen(substitute(getline(line), ".", "x", "g"))
		" also count newlines
		let chars += 1
		let line += 1
	endwhile
	return chars
endfun

" @return 0 if no match, 1 if match without wrap, 2 if match with wrap
fun! s:FindNext(start, strict, wrap)
	let ret = 0

	if !a:strict || (line(".") == 1 && virtcol(".") == 1)
		delmarks <>

		let @/ = s:search_str
		exe "normal! gn\<esc>"

		if line("'<") == 0
			norm m<m>
			return 0
		endif
		let ret = 1
	else
		" fix "s/aa/a" for "aaaa" and "s/x../xz" for "xyyxyy"
		" note you can't use delmarks to check if gn found a match, the search needs marks <> for limits

		" setpos won't work for '<'>, I don't understand...
		" note that \%'< wouldn't work here as reliably.
		call setpos("'<", a:start)
		call setpos("'>", [0, line("$"), col([line('$'), '$']), 0])

		" i have no fucking idea why this was needed, but it was. otherwise you get "not found" errors, so better keep it even if it seemingly can work without
		let temp = winsaveview()
		exe "norm! gv\<esc>"
		call winrestview(temp)

		normal! h
		let before_search = getpos(".")

		" watch out, using silent instead of exe might break moving to the next match
		keepj exe "normal! /\\%V\\(" . s:search_str . s:end_paren . "\<cr>\<esc>"
		" get the boundaries for the current match
		" gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. most notably when the match is 1 char long and on the last col of a line. sometimes gn only selects the first char when the search string is complex. this may break the whole substitution at worst
		exe "normal! gn\<esc>"

		" doesn't remove the existing entry if the user at some point happened to search for the exact same string as above. cool. probably thanks to :h function-search-undo?
		call histdel("/", -1)
		let @/ = s:search_str

		if a:wrap && getpos(".") == before_search
			let &wrapscan = 1
			keepj exe "norm! ngn\<esc>`<"
			" note: this fails when the match is 1 char long, it's the only match in the buffer, and the function gets called after replacing the match with the exact same char - after a substitution the cursor will initially be to the right of the "new" match, so when we move it to the left on top of that match and wrap around with search, we'll not move at all even though a match was found
			if getpos(".") != before_search
				let ret = 2
			endif
		else
			let ret = 1
		endif

	endif

	keepj norm! `<
	return ret
endfun

fun! easyreplace#EasyReplaceToggleUsePrevious()
	let s:use_prev = !s:use_prev
endfun

fun! easyreplace#EasyReplaceInitiate(init_cmd)
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	let s:use_prev = 0

	let separator_i = s:FindSeparator(a:init_cmd)
	if separator_i < 0
		return
	endif
	let s:sep = strpart(a:init_cmd, separator_i, 1)
	" escape the separator for the split regex if necessary
	let sep_esc = escape(s:sep, '/.*$^')
	let substrings = split(strpart(a:init_cmd, separator_i+1), '\C\v\\@<!(\\\\)*\zs'.sep_esc, 1)
	let s:search_str = substrings[0]
	if s:search_str ==# ""
		let s:search_str = @/
	endif
	let s:replace_str = get(substrings, 1, "")
	" if the last group (flags) is present in the substitute operation
	if len(substrings) == 3
		call s:DefineFlags(substrings[2])
	else
		let s:flags = "e"
	endif
	let s:end_paren = "\\)"
	" choose the later parenthesis (defined by the presence of \v) to surround all the search string. this way \%V will always be applied to the whole search string, even with alternations present. it also makes ^ and such work in search
	if s:IsVeryMagic(s:search_str)
		let s:end_paren = ")"
	endif
	"echo 'end_paren: '.s:end_paren
	let s:search_str = s:search_str
	let @/ = s:search_str
	let s:prev_pos = [0, 0, 0, 0]

	" the marks get changed at feedkeys anyway, so this doesn't really help. not a biggie though, not worth putting to feedkeys
	call setpos("'<", original_left)
	call setpos("'>", original_right)

	" ugly ahead: add search to the history, trigger highlighting if hlsearch is on, and move to the closest occurrence
	" histadd can cause duplicate entries, this should have no side effects
	" gn might fail on some searches resultin to a mark not set error or moving to wrong position
	call feedkeys(":let g:erepl_prev_pos = winsaveview()\<cr>/".@/."\<cr>:call winrestview(g:erepl_prev_pos)\<cr>gn\<esc>`<:echo ''\<cr>", 'n')
	call feedkeys(g:erepl_after_initiate)
endfunction

" doesn't force highlight if it was disabled by the user after the initiation cmd, user can just press "n" to get it back
fun! easyreplace#EasyReplaceDo()
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	let user_wrapscan = &wrapscan
	let user_virtualedit = &virtualedit
	let user_whichwrap = &whichwrap

	let msg_len = float2nr(winwidth(0) / 1.5) - 17

	if s:use_prev
		let s:sep = "/"
		let s:flags = "&"
		let s:replace_str = "~"
		if s:search_str != @/
			let s:search_str = @/
			let s:prev_pos = [0, 0, 0, 0]
			call s:DefineParen()
		endif
	else
		if s:search_str ==# ""
			return
		endif
		let @/ = s:search_str
	endif

	set whichwrap+=l
	set virtualedit=onemore

	let curr_pos = getpos(".")
	" if the cursor is where the previous substitution left it, operate strictly. trying to emulate CursorMoved autocmd, obviously works differently when moving around and returning back, but that might not be bad at all
	if s:FindNext(curr_pos, curr_pos == s:next_pos, user_wrapscan) == 1

		let user_reg = getreg('"')
		let user_reg_type = getregtype('"')
		exe "normal! gvy\<esc>"
		let match = @"
		call setreg(@", user_reg, user_reg_type)
		" mark the first char of the next result so that the whole result (and not others, so no need to worry about the 'g' flag) is affected by \%V. \%'< would really do the same thing but this seems neater and works for sure
		normal! m<m>
		let original_line = line(".")
		let original_col = virtcol(".")

		let match_len = strlen(substitute(match, ".", "x", "g"))
		"echo "@\"".match
		let match_height = s:SubStrCount(match, '\n', match_len) + 1
		"echo "match_len".match_len
		"echo "match_height".match_height

		let end_line = original_line + match_height - 1
		let chars_before = s:CountChars(original_line, end_line)
		"echo "chars_before" . chars_before

		exe "keepj '<,'>s" . s:sep . "\\%V\\%(" . s:search_str . s:end_paren . s:sep . s:replace_str . s:sep . s:flags

		let chars_after = s:CountChars(original_line, line("."))
		"echo "chars_after" . chars_after
		let offset = match_len + (chars_after - chars_before)
		"echo "offset" . offset
		keepj exe 'normal! `<'
		if offset > 0
			exe 'normal! ' . offset . 'l'
		endif

		call histdel("/", -1)
		let @/ = s:search_str

	endif

	" these should technically go to feedkeys, now they aren't always shown
	let found = s:FindNext(getpos("."), 1, user_wrapscan)
	if found > 0
		echo "/" . strpart(s:search_str, 0, msg_len)
	else
		echo "No more matches: " . strpart(s:search_str, 0, msg_len)
	endif

	let s:next_pos = getpos(".")

	let &virtualedit = user_virtualedit

	let &wrapscan = user_wrapscan
	let &whichwrap = user_whichwrap

	call setpos("'<", original_left)
	call setpos("'>", original_right)

	call feedkeys(g:erepl_after_replace)
	" clear up unnecessary error prompts caused by "not found" problems (which I can't get rid of because using silent to mute those seems to have weird side effects).
	call feedkeys("\<esc>", 'n')
endfunction
