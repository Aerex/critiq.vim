fu! s:on_pr_comments(response)
  let t:critiq_pr_comments = a:response.body
endfu

fu! s:submit_review(event)
	let body = join(getline(1, '$'), "\n")
	call critiq#pr#submit_review(t:critiq_pull_request, a:event, body)
    call critiq#review#delete_pending_request_review(t:critiq_pull_request)
	bd
    " Refresh comments on pull request view
	call critiq#views#pr#refresh(t:critiq_pull_request)
endfu

fu! critiq#views#review#render(state)
	let pr = t:critiq_pull_request
	belowright new
	resize 10
	let t:critiq_pull_request = pr
	let b:critiq_state = a:state
	setl buftype=nofile
	setl noswapfile

	command! -buffer CritiqSubmitReview call s:submit_review(b:critiq_state)

	call critiq#pr_tab_commands()

	if !exists('g:critiq_no_mappings')
		nnoremap <buffer> <silent> q :bd<cr>
		nnoremap <buffer> <silent> <cr> :CritiqSubmitReview<cr>
		call critiq#pr_tab_mappings()
	endif

	call critiq#trigger_event('CritiqReview')

	startinsert
endfu

