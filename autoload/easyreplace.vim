" Whether to use the latest search and latest substitution replacement (~) to find and replace when executing EasyReplaceDo
let s:use_prev = 1
" The string to be replaced with replace_str, also used for finding matches
let s:match_str = ''
" String to replace match_str
let s:replace_str = ''
" Flags of the substitution
let s:flags = ''
" The whole search is enclosed in one set of parentheses, and depending of the magic type of the search we either need to escape the latter paren or not
let s:end_paren = '\)'
" The position where the cursor left off after the last substitution operation
let s:next_pos = [0, 0, 0, 0]


" returns the index of the separator used in a subsitution command
fun! easyreplace#FindSeparator(subst_cmd)
	let separator_i = -1
	let cont = 1
	" note that multi-byte chars throw this off, doesn't matter here because the result is used as a byte-wise index
	let len = strlen(a:subst_cmd)
	let i = 0
	while i < len && cont
		if strpart(a:subst_cmd, i, 1) ==# 's'
			let separator_i = match(a:subst_cmd, '\C\v((substitute|substitut|substitu|substit|substi|subst|subs|sub|su|s) *)@<=[^0-9A-Za-z_ ]', i)
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


" returns the parts of a substitution cmd in a 4-element array as [range, match, replace, flags]
" range and flags are trimmed
" if there are missing parts they're represented by empty strings
" if there is no separator after the 's' part an empty array is returned
fun! easyreplace#ParseSubstitution(cmd)
	let separator_i = easyreplace#FindSeparator(a:cmd)
	if separator_i < 0
		return []
	endif
	let sep = strpart(a:cmd, separator_i, 1)
	" escape the separator for the split regex if necessary (if it's a special char with verymagic)
	let sep_esc = escape(sep, '/.?=%@*+&<>()[]{}^$~|\')

	let substrings = split(strpart(a:cmd, separator_i+1), '\v\\@<!(\\\\)*\zs'.sep_esc, 1)
	let range = strpart(a:cmd, 0, separator_i)
	let len = len(substrings) + 1

	let range = substitute(range, '\C\v *(substitute|substitut|substitu|substit|substi|subst|subs|sub|su|s) *$', '', '')
	let range = substitute(range, '\v^ +', '', '')

	let parts = []
	call add(parts, range)
	for str in substrings
		call add(parts, str)
	endfor

	let empty_places = 4 - len
	while empty_places > 0
		call add(parts, '')
		let empty_places -= 1
	endwhile

	if len > 3
		let parts[3] = substitute(parts[3], '\v^ +| +$', '', 'g')
	endif

	return parts
endfun


fun! easyreplace#MatchBackwards(str, match)
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


fun! easyreplace#IsVeryMagic(search)
	let magic = ""
	" get the last magic operator
	let magic_i = easyreplace#MatchBackwards(a:search, '\C\v\\@<!(\\\\)*\zs\\(v|m|M|V)')
	if magic_i >= 0
		let magic = strpart(a:search, magic_i, 2)
	endif
	"" slow regex
	"let magic = matchstr(a:search, '\v\C(\\@<!(\\\\)*\zs\\(v|m|M|V))@<!.*\\@<!(\\\\)*\zs\\(v|m|M|V)')
	if magic ==# '\v'
		return 1
	endif
	return 0
endfun


fun! easyreplace#SubStrCount(str, match)
	let found = 0
	let len = len(a:str)
	let i = 0
	while i < len && i >= 0
		let i = match(a:str, a:match, i)
		if i >= 0
			let found += 1
			let i += 1
		endif
	endwhile
	return found
endfun


fun! easyreplace#CountChars(start_line, end_line)
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


fun! s:HandleFlags(flags)
	let s:flags = a:flags

	" remove possible "c" flag
	let s:flags = substitute(s:flags, '\Cc', '', "g")

	" conform to possible "I"/"i" flag
	let big_i = match(s:flags, '\CI')
	if big_i > -1
		let s:match_str .= "\\C"
	endif
	if match(s:flags, '\Ci') > big_i
		let s:match_str .= "\\c"
	endif
endfun


fun! s:HandleZsZe(search)
	let parts = split(a:search, '\C\v\\@<!(\\\\)*\zs\\zs')
	let zs = ''
	let match_index = 0
	if len(parts) > 1
		let zs = parts[0]
		let esc = '\'
		if easyreplace#IsVeryMagic(zs)
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
		if easyreplace#IsVeryMagic(parts[0])
			let start_esc = ''
		endif
		let end_esc = '\'
		if easyreplace#IsVeryMagic(a:search)
			let end_esc = ''
		endif
		let ze = start_esc . '%(' . ze . end_esc . ')' . end_esc . '@='
	endif
	let parts = split(a:search, '\C\v\\@<!(\\\\)*\zs\\(zs|ze)')
	return zs . parts[match_index] . ze
endfun


fun! s:InitPrevSearch()
	let s:flags = "&"
	let s:replace_str = "~"
	if s:match_str ==# @/
		return
	endif
	let s:match_str = @/
	" this makes sure we don't ever match strictly when useprev is enabled
	let s:next_pos = [0, 0, 0, 0]
	let s:match_str = s:HandleZsZe(s:match_str)
	" make sure there are no unescaped slashes (from substitutions using custom delimiters)
	" doesn't remove possible escaped custom delimiters
	let s:match_str = substitute(s:match_str, '\C\v\\@<!(\\\\)*\zs/', '\\/', "g")
	if easyreplace#IsVeryMagic(s:match_str)
		let s:end_paren = ')'
	else
		let s:end_paren = '\)'
	endif
endfun


" @return 0 if no match, 1 if match without wrap, 2 if match with wrap
" mark the match with '< and '> if one was found
" end_paren can either be ')' if the match pattern uses verymagic or '\)' otherwise
" note: will wrap regardless of the 'nowrap' option, even though it shouldn't
fun! s:FindNext(match, start, strict, wrap, end_paren)
	let ret = 0

	" if the search wasn't strict, we can match any hit that the cursor is on (not just those that start at the cursor), and even hits behind the cursor if wrap is enabled. if we're on the first character of the buffer we don't have to worry about any of that
	" the delmarks approach seems to work here, not sure why
	if !a:strict || (line(".") == 1 && virtcol(".") == 1)
		delmarks <>

		let @/ = a:match
		exe "normal! gn\<esc>"

		if line("'<") < 1
			" make sure the marks exist
			norm! m<m>
		else
			let ret = 1
		endif
	" fix "s/aa/a" for "aaaa" and "s/x../xz" for "xyyxyy" by disallowing matches whose first character is behind the cursor
	else
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
		keepj exe "silent! normal! /\\%V\\(" . a:match . a:end_paren . "\<cr>\<esc>"

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


fun! s:FindPrev(match)
	let ret = 1

	" there's no special treatment for the last char of the buffer because when this is called virtualedit=onemore will be set and the 'l' can still move the cursor
	normal! l
    let before_search = getpos(".")

	keepj exe "silent! normal! ?" . a:match . "\<cr>\<esc>"

	exe "normal! gno\<esc>"

	call histdel("/", -1)
	let @/ = a:match

	if getpos(".") == before_search
		let ret = 0
		norm! m<m>
	endif

	keepj norm! `<
	return ret
endfun


fun! s:GetMsgLen()
	return float2nr(winwidth(0) / 1.5) - 17
endfun


fun! easyreplace#EasyReplaceToggleUsePrevious()
	let s:use_prev = !s:use_prev
	echo s:use_prev ? 'Mode: Use latest search' : 'Mode: Ignore searches'
endfun


fun! easyreplace#EasyReplaceInitiate(init_cmd)
	" make sure the marks exist, they're used later
	if line("'<") < 1
		call setpos("'<", '.')
		call setpos("'>", '.')
	endif

	" stop using latest substitution/search commands if explicitly initiated
	let s:use_prev = 0

	let parts = easyreplace#ParseSubstitution(a:init_cmd)

	let s:match_str = parts[1]
	if s:match_str ==# ""
		let s:match_str = @/
	elseif g:erepl_always_verymagic && match(s:match_str, '\C\v^\\(v|m|V|M)') < 0
		let s:match_str = '\v' . s:match_str
	endif
	let s:match_str = s:HandleZsZe(s:match_str)

	let s:replace_str = parts[2]

	call s:HandleFlags(parts[3])

	let s:end_paren = '\)'
	" choose the later parenthesis (defined by the presence of \v) to surround all the search string. this way \%V will always be applied to the whole search string, even with alternations present. it also makes ^ and such work in search
	if easyreplace#IsVeryMagic(s:match_str)
		let s:end_paren = ")"
	endif

	" if we use the previous search (leave the match part empty) and it was initiated from a substitution with a custom delimiter, vim will put the slashes non-escaped into the search register. however in order to use the previous search in the substitution all slashes that are NOT already escaped need to be escaped
	" same thing if the current substitution is written using a custom delimiter, all non-escaped slashes must be escaped
	" so we can safely escape non-escaped slashes in any situation
	" custom delimiters leave unnecessary escapes in the match, but vim luckily ignores them as long as their escaped forms aren't special characters in the current regex mode (which they shouldn't be)
	" always using '/' as the delimiter is smart because that way there won't be problems differentiating between escaped delimiters and escaped special characters
	let s:match_str = substitute(s:match_str, '\C\v\\@<!(\\\\)*\zs/', '\\/', "g")

	let @/ = s:match_str

	" this makes sure we don't match strictly when executing the first substitution
	let s:next_pos = [0, 0, 0, 0]

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

	let msg_len = s:GetMsgLen()

	let cycles = 0
	let times = v:count1
	while cycles < times

		if s:use_prev
			call s:InitPrevSearch()
		else
			if s:match_str ==# ""
				return
			endif
			let @/ = s:match_str
		endif

		set whichwrap+=l
		set virtualedit=onemore

		let curr_pos = getpos(".")
		" if the cursor is where the previous substitution left it, operate strictly. trying to emulate CursorMoved autocmd, obviously works differently when moving around and returning back, but that might not be bad at all
		" there's still a bug with lookbehinds. when you do a substitution it can change the results of the lookbehinds ahead of the substitution you just did. this can add new matches or remove existing matches unwantedly between substitutions. there's absolutely no way around this: if you store the next match before the substitution takes place, and remove lookbehinds from the substitution, you mess up backreferences and stuff. if you do a copy of the original buffer to locate matches, you can't edit anything so you might as well use the 'c' flag with a normal substitution instead.
		if s:FindNext(s:match_str, curr_pos, curr_pos == s:next_pos, user_wrapscan, s:end_paren) == 1

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

			" newlines should also count for length because virtualedit is enabled. '.' works in the pattern too
			let match_len = strlen(substitute(match, '\_.', 'x', 'g'))
			let match_height = easyreplace#SubStrCount(match, '\n') + 1

			let end_line = original_line + match_height - 1
			let chars_before = easyreplace#CountChars(original_line, end_line)

			exe "keepj '<,'>s/\\%V\\%(" . s:match_str . s:end_paren . '/' . s:replace_str . '/' . s:flags . 'e'

			let chars_after = easyreplace#CountChars(original_line, line("."))
			let offset = match_len + (chars_after - chars_before)
			keepj exe 'normal! `<'
			if offset > 0
				exe 'normal! ' . offset . 'l'
			endif

			call histdel("/", -1)

		endif

		let found = s:FindNext(s:match_str, getpos("."), 1, user_wrapscan, s:end_paren)

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


fun! easyreplace#EasyReplaceDoBackwards()
	let original_left = getpos("'<")
	let original_right = getpos("'>")

	let user_wrapscan = &wrapscan
	let user_virtualedit = &virtualedit
	let user_whichwrap = &whichwrap

	let msg_len = s:GetMsgLen()

	let cycles = 0
	let times = v:count1
	while cycles < times

		if s:use_prev
			call s:InitPrevSearch()
		else
			if s:match_str ==# ""
				return
			endif
			let @/ = s:match_str
		endif

		set whichwrap+=l
		set virtualedit=onemore

		let found = 0
		if s:FindPrev(s:match_str) == 1

			let view = winsaveview()

			norm! h
			let found = s:FindPrev(s:match_str)
			let s:next_pos = getpos(".")

			call winrestview(view)
			normal! m<m>

			exe "keepj '<,'>s/\\%V\\%(" . s:match_str . s:end_paren . '/' . s:replace_str . '/' . s:flags . 'e'

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


fun! easyreplace#SubstituteArea()
	if s:use_prev
		call s:InitPrevSearch()
	else
		if s:match_str ==# ""
			return
		endif
		let @/ = s:match_str
	endif

	let search = @/

	exe "silent! keepj '<,'>s/\\%V\\%(" . s:match_str . s:end_paren . '/' . s:replace_str . '/' . s:flags . 'e'

	call histdel("/", -1)
	let @/ = search

	redraw
	let msg_len = s:GetMsgLen()
	let msg = strpart(s:match_str, 0, msg_len)
	echo msg
endfun
