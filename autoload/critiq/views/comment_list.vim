
if !exists('g:critiq_comment_list_width')
	let g:critiq_comment_list_width = 80
endif

let s:comment_line_numbers = []

fu! critiq#views#comment_list#next()
  let line_nbr = line('.') 
  let sorted_line_nbrs = sort(keys(t:critiq_comment_line_number_map))
  let last_comment_line_nbr = sorted_line_nbrs[len(sorted_line_nbrs) - 1]
  if line_nbr == last_comment_line_nbr 
    if exists('g:critiq_comment_navigate_no_wrap')
      let next_comment_line_nbr_index = len(s:comment_line_numbers) - 1
    else
      let next_comment_line_nbr_index = 0
    endif
    exec s:comment_line_numbers[next_comment_line_nbr_index]
    return
  endif
  if !has_key(t:critiq_comment_line_number_map, line_nbr)
    let next_comment_line_nbr_index = 0
    for current_line_nbr in sorted_line_nbrs
      if str2nr(current_line_nbr) > str2nr(line_nbr)
        let next_comment_line_nbr_index = t:critiq_comment_line_number_map[current_line_nbr]['index']
        break
      endif
    endfor
  else
    let next_comment_line_nbr_index = t:critiq_comment_line_number_map[line_nbr]['index'] + 1
  endif
  exec s:comment_line_numbers[next_comment_line_nbr_index]
endfu

fu! critiq#views#comment_list#prev()
  let line_nbr = line('.') 
  let sorted_line_nbrs = sort(keys(t:critiq_comment_line_number_map))
  let first_comment_line_nbr = sorted_line_nbrs[0]
  if line_nbr == first_comment_line_nbr 
    if exists('g:critiq_comment_navigate_no_wrap')
      let next_comment_line_nbr_index = t:critiq_comment_line_number_map[first_comment_line_nbr]['index'] 
    else
      let next_comment_line_nbr_index = len(s:comment_line_numbers) - 1 
    endif
    exec s:comment_line_numbers[next_comment_line_nbr_index]
    return
  endif
  if !has_key(t:critiq_comment_line_number_map, line_nbr)
    let next_comment_line_nbr_index = len(s:comment_line_numbers) - 1 
    for current_line_nbr in sorted_line_nbrs
      if str2nr(current_line_nbr) < str2nr(line_nbr)
        let next_comment_line_nbr_index = t:critiq_comment_line_number_map[current_line_nbr]['index']
        break
      endif
    endfor
  else
    let next_comment_line_nbr_index = t:critiq_comment_line_number_map[line_nbr]['index'] - 1
  endif
  exec s:comment_line_numbers[next_comment_line_nbr_index]
endfu

fu! critiq#views#comment_list#render() abort
  if !exists('t:critiq_comment_line_number_map')
    let t:critiq_comment_line_number_map = {}
  endif

  let line_diff = t:critiq_pr_diff[line('.')]
  let position = line_diff.file_index - 1
  let comments = []
  let maxchars = g:critiq_comment_list_width - 5
  let bar = repeat('-', maxchars)
  let comment_line_number = 3
  let comment_line_number_index = 0

  for comment in t:critiq_pr_comments
    if comment.path == line_diff.file && comment.position == position
      if len(comments) > 0
        call extend(comments, ['', bar])
      endif
      let username = comment.user.login
      let timestamp = comment.created_at
      let padding = repeat(' ', maxchars - len(timestamp) - len(username))
      call add(comments, username . padding . timestamp)
      call add(comments, '')
      call extend(comments, split(comment.body, "\n"))
      call add(s:comment_line_numbers, comment_line_number)
      let t:critiq_comment_line_number_map[comment_line_number] = { 
            \'index': comment_line_number_index, 
            \'body': split(comment.body, "\n"), 
            \'comment_id': comment.id 
            \}
      let comment_line_number = comment_line_number + 5
      let comment_line_number_index = comment_line_number_index + 1
    endif 
  endfor

  vertical belowright new
  exe 'vertical resize' g:critiq_comment_list_width
  setl buftype=nofile
  setl noswapfile
  call setline(1, comments)
  set ft=markdown
  setl nomodifiable

  for comment_line_nbr in keys(t:critiq_comment_line_number_map)
    exe 'sign place ' . comment_line_nbr ' line=' . comment_line_nbr . ' name=critiqremotecomment buffer=' . bufnr('%')
  endfor

  command! -buffer CritiqCommentNext call critiq#views#comment_list#next()
  command! -buffer CritiqCommentPrev call critiq#views#comment_list#prev()
  command! -buffer CritiqCommentEdit call critiq#views#edit_comment#render()

  if !exists('g:critiq_no_mappings')
    nnoremap <buffer> <silent> q     :bd<cr>
    nnoremap <buffer> <silent> <c-n> :CritiqCommentNext<cr>
    nnoremap <buffer> <silent> <c-p> :CritiqCommentPrev<cr>
    nnoremap <buffer> <silent> e     :CritiqCommentEdit<cr>
  endif
endfu
