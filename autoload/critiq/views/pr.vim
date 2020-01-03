
" Code for rendering the buffer which contains the diff of the pr, etc.

fu! s:on_open_pr(response)
  let t:critiq_pull_request = a:response['body']

	command! -buffer CritiqApprove call critiq#views#review#render('APPROVE')
	command! -buffer CritiqRequestChanges call critiq#views#review#render('REQUEST_CHANGES')
    command! -buffer CritiqRequestPendingChanges call critiq#review#request_pending_review(t:critiq_pull_request)
	command! -buffer CritiqComment call critiq#views#review#render('COMMENT')
	command! -buffer CritiqCommentLine call critiq#views#comment#render()
	command! -buffer CritiqOpenFile call critiq#views#pr_file#render()
	command! -buffer CritiqListComments call critiq#views#comment_list#render()
	command! -buffer CritiqListCommits call critiq#views#commit_list#render()

	call critiq#pr_tab_commands()

	if !exists('g:critiq_no_mappings')
		nnoremap <buffer> <silent> q          :tabc<cr>
		nnoremap <buffer> <silent> ra         :CritiqApprove<cr>
		nnoremap <buffer> <silent> rr         :CritiqRequestChanges<cr>
		nnoremap <buffer> <silent> rp         :CritiqRequestPendingChanges<cr>
		nnoremap <buffer> <silent> rc         :CritiqComment<cr>
		nnoremap <buffer> <silent> c          :CritiqCommentLine<cr>
		nnoremap <buffer> <silent> C          :CritiqListComments<cr>
		nnoremap <buffer> <silent> gf         :CritiqOpenFile<cr>
		nnoremap <buffer> <silent> <leader>C  :CritiqListCommits<cr>
		call critiq#pr_tab_mappings()
	endif

	call critiq#trigger_event("CritiqPr")

	call s:render_pr_comments()
endfu

fu! s:on_pr_comments(response)
	let t:critiq_pr_comments = a:response.body
	call s:render_pr_comments()
endfu
fu! s:on_pr_comments_refresh(response)
    call s:on_pr_comments(a:response)
endfu

fu! s:echo_cursor_comment()
	if exists('t:critiq_pr_comments')
		if !exists('b:critiq_last_position') || b:critiq_last_cursor_position != line('.')
			let b:critiq_last_cursor_position = line('.')
			if has_key(t:critiq_pr_comments_map, line('.'))
				let comment = t:critiq_pr_comments_map[line('.')]
				echom comment.body
				let b:critiq_echo_cleared = 0
			elseif exists('b:critiq_echo_cleared') && !b:critiq_echo_cleared
				echo
				let b:critiq_echo_cleared = 1
			endif
		endif
	endif
endfu

fu! s:set_comment_line_sign(comment, comment_sign_name, is_local_comment)
  let line_number = 1
  for line_diff in t:critiq_pr_diff
    if empty(line_diff) || (exists('t:critiq_pr_comments_map') && a:is_local_comment && has_key(t:critiq_pr_comments_map, line_number))
      let line_number += 1
      continue
    endif

    if a:comment.path == line_diff.file && line_diff.file_index == a:comment.position
      let t:critiq_pr_comments_map[line_number] = a:comment
      exe 'sign place ' . line_number ' line=' . line_number . ' name=' . a:comment_sign_name .' buffer=' . bufnr('%')
    endif
    let line_number += 1
  endfor
endfu

fu! s:render_pr_comments()
  echo 't:critiq_pr_comments_loaded ' . exists('t:critiq_pr_comments_loaded') 
  "echo 't:critiq_pull_request ' .  exists('t:critiq_pull_request')

  "echo 't:critiq_pr_comments' . exists('t:critiq_pr_comments')

	if (!exists('t:critiq_pr_comments_loaded') || (exists('t:critiq_pr_comments_loaded') && t:critiq_pr_comments_loaded == 0)) && exists('t:critiq_pull_request') && exists('t:critiq_pr_comments') 
      echo 'enter render_pr_comments'
		let t:critiq_pr_comments_loaded = 1
		let t:critiq_pr_comments_map = {}
		exe 'sign define critiqremotecomment text=' . g:critiq_comment_symbol . ' texthl=Search'
		exe 'sign define critiqlocalcomment text=' . g:critiq_comment_symbol . ' texthl=' . g:critiq_local_comment_highlight

		let pr = t:critiq_pull_request
		for comment in t:critiq_pr_comments
			if pr.head.sha == comment.commit_id
              call s:set_comment_line_sign(comment, 'critiqremotecomment', 0)
			endif
		endfor

        let local_pending_review = critiq#review#local_pending_review_exists(pr) 

        if local_pending_review
          let local_pending_review = critiq#review#get_local_pending_review(pr) 
          for comment in local_pending_review.comments
            call s:set_comment_line_sign(comment, 'critiqlocalcomment', 1)
          endfor
        endif
		" This is for truncating the message body...
		setl shortmess+=T
		autocmd CursorMoved <buffer> call s:echo_cursor_comment()
	endif
endfu

fu! s:edit_label_mappings()
	command! -buffer CritiqEditLabels call critiq#views#label_list#render()
	if !exists('g:critiq_no_mappings')
		nnoremap <buffer> <leader>l :CritiqEditLabels<cr>
	endif
endfu

fu! s:on_repo_labels(response)
	let t:critiq_repo_labels[t:critiq_repo_url] = a:response
	call s:edit_label_mappings()
endfu

fu! s:on_open_pr_diff(response)
	let text = a:response['body']
	let pr = t:critiq_pull_requests[line('.') - 1]
	let repo_labels = t:critiq_repo_labels

	tabnew
	setl buftype=nofile
	setl noswapfile
	call setline(1, text)
	setl nomodifiable
	let t:critiq_pr_diff = critiq#diff#parse(text)
	let t:critiq_repo_labels = repo_labels
	setf diff

	let t:critiq_repo_url = critiq#pr#repo_url(pr)
	if has_key(t:critiq_repo_labels, t:critiq_repo_url)
		call s:edit_label_mappings()
	else
		call critiq#pr#repo_labels(pr, function('s:on_repo_labels'))
	endif

	call critiq#pr#pull_request(pr, function('s:on_open_pr'))
	call critiq#pr#pr_comments(pr, function('s:on_pr_comments'))
	call critiq#views#pr_header#render(pr)
endfu

fu! critiq#views#pr#render()
	let pr = t:critiq_pull_requests[line('.') - 1]
	call critiq#pr#diff(pr, function('s:on_open_pr_diff'))
endfu

fu! critiq#views#pr#refresh(pr)
   let t:critiq_pr_comments_loaded = 0
	call critiq#pr#pr_comments(a:pr, function('s:on_pr_comments_refresh'))
endfu
