" Whether to use the latest search and latest substitution replacement (~) to find and replace when executing EasyReplaceDo
let s:use_prev = 1
" Separator used in substitution
let s:sep = "/"
" The string to be used in the replace operation
let s:search_str = ""
" The string to be used for finding matches. Unlike search_str, this can't have special delimiters so instead '/' will always be eascaped and custom delimiters will be de-escaped if they were given
let s:match_str = ""
" String to replace search_str with
let s:replace_str = ""
" Flags of the substitution
let s:flags = ""
" The whole search is enclosed in one set of parentheses, and depending of the magic type of the substitution, we either need to escape the latter paren or not
let s:end_paren = "\\)"
" The position where the cursor left off after the last substitution operation
let s:next_pos = [0, 0, 0, 0]


" pretty unnecessary, but fun
fun! s:FindSeparator(subst_cmd)
	let separator_i = -1
	let cont = 1
	" note that multi-byte chars throw this off, doesn't matter here because the result is used as a byte-wise index
	let len = strlen(a:subst_cmd)
	let i = 0
	while i < len && cont
		if strpart(a:subst_cmd, i, 1) ==# 's'
			let separator_i = match(a:subst_cmd, '\C\v(s|su|sub|subs|subst|substi|substit|substitu|substitut|substitute)@<=[^0-9A-Za-z_ ]', i)
			let cont = 0
		elseif strpart(a:subst_cmd, i, 1) ==# "'"
			let i += 2
		elseif strpart(a:subst_cmd, i, 1) ==# '/'
			let i = match(a:subst_cmd, '\v\\@<!(\\\\)*\zs/', i+1)
			if i < 0
				let cont = 0
			endif
			let i+= 1
		else
			let i += 1
		endif
	endwhile
	return separator_i
endfun

fun! s:DefineFlags(flags_string)
	let s:flags = a:flags_string
	" remove possible "c" flag
	let s:flags = substitute(s:flags, '\Cc', '', "g")
	" conform to possible "I"/"i" flag
	let big_i = match(s:flags, '\CI')
	if big_i > -1
		let s:search_str .= "\\C"
	endif
	if match(s:flags, '\Ci') > big_i
		let s:search_str .= "\\c"
	endif
	" add e flag to suppress errors
	let s:flags .= 'e'
endfun

fun! s:MatchBackwards(str, match)
	" note that multi-byte chars throw this off, doesn't matter here because the result is used as a byte-wise index
	let i = 0
	let found = -1
	while i >= 0
		let i = match(a:str, a:match, i)
		if i >= 0
			let found = i
			let i += 1
		endif
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
	"let magic = matchstr(a:search_str, '\v\C(\\@<!(\\\\)*\zs\\(v|m|M|V))@<!.*\\@<!(\\\\)*\zs\\(v|m|M|V)')
	if magic ==# '\v'
		return 1
	endif
	return 0
endfun

fun! s:RemoveZsZe(search)
	let parts = split(a:search, '\C\v\\@<!(\\\\)*\zs\\zs')
	let zs = ''
	let match_index = 0
	if len(parts) > 1
		let zs = parts[0]
		let esc = '\'
		if s:IsVeryMagic(zs)
			let esc = ''
		endif
		let zs = '\%(' . zs . esc . ')' . esc . '@<='
		let match_index = 1
	endif
	let parts = split(a:search, '\C\v\\@<!(\\\\)*\zs\\ze')
	let ze = ''
	if len(parts) > 1
		let ze = parts[1]
		let start_esc = '\'
		if s:IsVeryMagic(parts[0])
			let start_esc = ''
		endif
		let end_esc = '\'
		if s:IsVeryMagic(a:search)
			let end_esc = ''
		endif
		let ze = start_esc . '%(' . ze . end_esc . ')' . end_esc . '@='
	endif
	let parts = split(a:search, '\C\v\\@<!(\\\\)*\zs\\(zs|ze)')
	return zs . parts[match_index] . ze
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

fun! s:CountChars(start_line, end_line)
	let line = a:start_line
	let chars = 0
	while line <= a:end_line
		let chars += strlen(substitute(getline(line), ".", "x", "g"))
		" also count newlines
		let chars += 1
		let line += 1
	endwhile
	return chars
endfun

" @return 0 if no match, 1 if match without wrap, 2 if match with wrap
" mark the match with '< and '> if one was found
" note: will wrap regardless of the 'nowrap' option, even though it shouldn't
fun! s:FindNext(match, start, strict, wrap)
	let ret = 0

	" if the search wasn't strict, we can match any hit that the cursor is on, and even hits behind the cursor if wrap is enabled. if we're on the first character of the buffer we don't have to worry about previous matches.
	" the delmarks approach seems to work here, not sure why
	if !a:strict || (line(".") == 1 && virtcol(".") == 1)
		delmarks <>

		let @/ = a:match
		exe "normal! gn\<esc>"

		if line("'<") < 1
			" make sure the marks exist
			norm! m<m>
			return 0
		endif
		let ret = 1
	else
		" fix "s/aa/a" for "aaaa" and "s/x../xz" for "xyyxyy" by disallowing matches whose first character is behind the cursor

		" note you can't use delmarks here. for some reason vim refuses to set the marks when you execute gn\<esc> within the script (extra gv doesn't help either), so even if a match is found and gn selects the area, it's still impossible to know there was a match because the marks aren't set
		" note that \%'< wouldn't work here reliably, better stick with \%V
		call setpos("'<", a:start)
		call setpos("'>", [0, line("$"), col([line('$'), '$']), 0])

		" without selecting the marks in visual mode you get false "not found" errors, so better keep it even if it seemingly can work without
		let temp = winsaveview()
		exe "norm! gv\<esc>"
		call winrestview(temp)

		normal! h
		let before_search = getpos(".")

		" watch out, using silent in place of exe might break moving to the next match
		" putting silent before normal should work
		" '/' wraps around regardless of the 'nowrap' setting, but setting the @/ register directly and doing 'n' doesn't help either so this will do
		keepj exe "silent! normal! /\\%V\\(" . a:match . s:end_paren . "\<cr>\<esc>"

		" get the boundaries for the current match
		" gn sometimes fails to keep the cursor still when the match is only 1 char long and you're on it. most notably when the match is 1 char long and on the last col of a line. sometimes gn only selects the first char when the search string is complex. this may break the whole substitution at worst
		exe "normal! gn\<esc>"

		" doesn't remove the existing entry if the user at some point happened to search for the exact same string as above. cool. probably thanks to :h function-search-undo?
		call histdel("/", -1)
		let @/ = a:match

		" if no match found but wrap is used
		if getpos(".") == before_search
			if a:wrap
				let &wrapscan = 1
				keepj exe "sil! norm! ngn\<esc>"
				" if a match was found after a wrap
				" note: this fails when the match is 1 char long, it's the only match in the buffer, and the function gets called after replacing the match with the exact same char - after a substitution the cursor will initially be to the right of the "new" match, so when we move it to the left on top of that match and wrap around with search, we'll not move at all even though a match was found
				if getpos(".") != before_search
					let ret = 2
				else
					" make sure the marks exist
					norm! m<m>
				endif
			else
				" make sure the marks exist
				norm! m<m>
			endif
		else
			let ret = 1
		endif

	endif

	keepj norm! `<
	return ret
endfun

fun! s:CheckPrevSearch()
	if s:use_prev
		let s:sep = "/"
		let s:flags = "&"
		let s:replace_str = "~"
		if s:match_str != @/
			let s:match_str = @/
			" this makes sure we don't ever match strictly when useprev is enabled
			let s:next_pos = [0, 0, 0, 0]
			let s:match_str = s:RemoveZsZe(s:match_str)
			" make sure there are no unescaped slashes (from substitutions using custom delimiters)
			" doesn't remove possible escaped custom delimiters
			let s:match_str = substitute(s:match_str, '\C\v\\@<!(\\\\)*\zs/', '\\/', "g")
			if s:IsVeryMagic(s:match_str)
				let s:end_paren = ")"
			else
				let s:end_paren = "\\)"
			endif
		endif
		let s:search_str = s:match_str
	else
		if s:match_str ==# ""
			return
		endif
		let @/ = s:match_str
	endif
endfun

fun! easyreplace#EasyReplaceToggleUsePrevious()
	let s:use_prev = !s:use_prev
	echo s:use_prev ? 'Mode: Use latest search' : 'Mode: Ignore searches'
endfun

fun! easyreplace#EasyReplaceInitiate(init_cmd)
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	" stop using latest substitution/search commands if explicitly initiated
	let s:use_prev = 0

	let separator_i = s:FindSeparator(a:init_cmd)
	if separator_i < 0
		return
	endif
	let s:sep = strpart(a:init_cmd, separator_i, 1)
	" escape the separator for the split regex if necessary (if it's a special char with verymagic)
	let sep_esc = escape(s:sep, '/.?=%@*+&<>()[]{}^$~|\')

	let substrings = split(strpart(a:init_cmd, separator_i+1), '\C\v\\@<!(\\\\)*\zs'.sep_esc, 1)

	let s:search_str = substrings[0]
	let was_empty = 0
	if s:search_str ==# ""
		let s:search_str = @/
		let was_empty = 1
	endif
	let s:replace_str = get(substrings, 1, "")
	" if the last group (flags) is present in the substitute operation
	if len(substrings) == 3
		call s:DefineFlags(substrings[2])
	else
		let s:flags = "e"
	endif

	if g:erepl_always_verymagic && match(s:search_str, '\v^\\(v|m|V|M)') < 0
		let s:search_str = '\v'. s:search_str
	endif

	let s:search_str = s:RemoveZsZe(s:search_str)

	let s:end_paren = "\\)"
	" choose the later parenthesis (defined by the presence of \v) to surround all the search string. this way \%V will always be applied to the whole search string, even with alternations present. it also makes ^ and such work in search
	if s:IsVeryMagic(s:search_str)
		let s:end_paren = ")"
	endif

	" the match string is different in that it always has slashes escaped (search requires it whether the substitution was given with "non-slash" delimiters or not). ONLY escape slashes if the delimiter used by the user was not a slash (otherwise they have it manually escaped already) AND the used search string isn't empty
	let s:match_str = s:search_str
	" if the previous search was initiated from a substitution with a custom delimiter, vim will put the slashes non-escaped into the search register. however in order to use the previous search in the substitution all slashes that are NOT already escaped need to be escaped
	" there can also be unnecessary escaspes if the custom delimiter was escaped in the previous substitution. no way to get rid of those, vim doesn't either. fortunately extra escapes don't cause trouble as long as the escaped delimiters don't have a special meaning in any regex mode. using such delimiters should never be done in the first place, and vim disallows most problematic substitutions I can think of
	if was_empty
		let s:match_str = substitute(s:match_str, '\C\v\\@<!(\\\\)*\zs/', '\\/', "g")
		" if the separator used for the current substitution was a slash, search_str needs to have all the slashes from the previous search escaped too
		if s:sep =~# '/'
			let s:search_str = substitute(s:search_str, '\C\v\\@<!(\\\\)*\zs/', '\\/', "g")
		endif
	elseif s:sep !~# '/'
		let s:match_str = escape(s:match_str, '/')
		" if a custom delimiter was used, we need to remove possible inputted extra escapes from the match string
		let s:match_str = substitute(s:match_str, '\C\v\\@<!(\\\\)*\zs\\'.sep_esc, s:sep, "g")
	endif

	let @/ = s:match_str

	" this makes sure we don't match strictly when executing the first substitution
	let s:next_pos = [0, 0, 0, 0]

	" the marks get changed at feedkeys anyway, so this doesn't really help. not a biggie though, not worth putting to feedkeys
	call setpos("'<", original_left)
	call setpos("'>", original_right)

	" ugly ahead: add search to the history, trigger highlighting if hlsearch is on, and move to the closest occurrence
	" histadd can cause duplicate entries, this should have no side effects
	" gn might fail on some searches resulting to a mark not set error or moving to wrong position
	call feedkeys(":let g:erepl_prev_pos = winsaveview()\<cr>/".@/."\<cr>:call winrestview(g:erepl_prev_pos)\<cr>gn\<esc>`<:echo ''\<cr>", 'n')
	call feedkeys(g:erepl_after_initiate, 'n')
endfunction

" doesn't force highlight if it was disabled by the user after the initiation cmd, user can just press "n" to get it back
fun! easyreplace#EasyReplaceDo()
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	let user_wrapscan = &wrapscan
	let user_virtualedit = &virtualedit
	let user_whichwrap = &whichwrap

	let msg_len = float2nr(winwidth(0) / 1.5) - 17

	let cycles = 0
	let times = v:count1
	while cycles < times

		call s:CheckPrevSearch()

		set whichwrap+=l
		set virtualedit=onemore

		let curr_pos = getpos(".")
		" if the cursor is where the previous substitution left it, operate strictly. trying to emulate CursorMoved autocmd, obviously works differently when moving around and returning back, but that might not be bad at all
		" there's still a bug with lookbehinds. when you do a substitution it can change the results of the lookbehinds ahead of the substitution you just did. this can add new matches or remove existing matches unwantedly between substitutions. there's absolutely no way around this: if you store the next match before the substitution takes place, and remove lookbehinds from the substitution, you mess up backreferences and stuff. if you do a copy of the original buffer to locate matches, you can't edit anything so you might as well use the 'c' flag with a normal substitution instead.
		if s:FindNext(s:match_str, curr_pos, curr_pos == s:next_pos, user_wrapscan) == 1

			let user_reg = getreg('"')
			let user_reg_type = getregtype('"')
			" select the match marked by FindNext and yank it
			exe "normal! gvy\<esc>"
			let match = @"
			call setreg('"', user_reg, user_reg_type)
			" mark the first char of the next result so that the whole result (and not others, so no need to worry about the 'g' flag) is affected by \%V
			normal! m<m>
			let original_line = line(".")
			let original_col = virtcol(".")

			let match_len = strlen(substitute(match, ".", "x", "g"))
			let match_height = s:SubStrCount(match, '\n', match_len) + 1

			let end_line = original_line + match_height - 1
			let chars_before = s:CountChars(original_line, end_line)

			exe "keepj '<,'>s" . s:sep . "\\%V\\%(" . s:search_str . s:end_paren . s:sep . s:replace_str . s:sep . s:flags

			let chars_after = s:CountChars(original_line, line("."))
			let offset = match_len + (chars_after - chars_before)
			keepj exe 'normal! `<'
			if offset > 0
				exe 'normal! ' . offset . 'l'
			endif

			call histdel("/", -1)

		endif

		let found = s:FindNext(s:match_str, getpos("."), 1, user_wrapscan)

		let s:next_pos = getpos(".")

		let cycles += 1
	endwhile

	" these should technically go to feedkeys
	let msg = strpart(s:match_str, 0, msg_len)
	if found == 1
		echo '/' . msg
	elseif found == 2
		echohl WarningMsg
		echo 'Wrapped around: ' . msg
		echohl None
	else
		echohl WarningMsg
		echo 'No more matches: ' . msg
		echohl None
	endif

	let &virtualedit = user_virtualedit

	let &wrapscan = user_wrapscan
	let &whichwrap = user_whichwrap

	call setpos("'<", original_left)
	call setpos("'>", original_right)

	call feedkeys(g:erepl_after_replace, 'n')
endfunction

fun! s:FindPrev(match)
	let ret = 1

	normal! l
    let before_search = getpos(".")

	keepj exe "normal! ?" . a:match . "\<cr>\<esc>"

	exe "normal! gn\<esc>"

	call histdel("/", -1)
	let @/ = a:match

	if getpos(".") == before_search
		let ret = 0
		norm! m<m>
	endif

	keepj norm! `<
	return ret
endfun

fun! easyreplace#EasyReplaceDoBackwards()
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	let user_wrapscan = &wrapscan
	let user_virtualedit = &virtualedit
	let user_whichwrap = &whichwrap

	let msg_len = float2nr(winwidth(0) / 1.5) - 17

	let cycles = 0
	let times = v:count1
	while cycles < times

		call s:CheckPrevSearch()

		set whichwrap+=l
		set virtualedit=onemore

		let found = 0
		if s:FindPrev(s:match_str) == 1

			let view = winsaveview()
			let original_line = line(".")

			norm! h
			let found = s:FindPrev(s:match_str)
			let s:next_pos = getpos(".")

			call winrestview(view)
			normal! m<m>
			norm! `<

			exe "keepj '<,'>s" . s:sep . "\\%V\\%(" . s:search_str . s:end_paren . s:sep . s:replace_str . s:sep . s:flags

			call setpos('.', s:next_pos)

			call histdel("/", -1)

		endif

		let cycles += 1
	endwhile

	let msg = strpart(s:match_str, 0, msg_len)
	if found == 1
		echo '?' . msg
	else
		echohl WarningMsg
		echo 'No earlier matches: ' . msg
		echohl None
	endif

	let &virtualedit = user_virtualedit

	let &wrapscan = user_wrapscan
	let &whichwrap = user_whichwrap

	call setpos("'<", original_left)
	call setpos("'>", original_right)

	call feedkeys(g:erepl_after_replace, 'n')
endfunction
