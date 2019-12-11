fu! s:local_pending_review_dir(pr)
  let reviews_dir = '/repos/' . a:pr['head']['repo']['full_name'] . '/pulls/' . string(a:pr['number']) . '/reviews'
  return $HOME . '/.local/share/critiq' . reviews_dir 
endfu

fu! s:write_review_file(pr)
  let pr_reviews_dir_names = split(s:local_pending_review_dir(a:pr), '/')
  let directories = []
  for dir_name in pr_reviews_dir_names 
    call add(directories, '/' . dir_name)
  endfor
  let pending_pr_comments_data = {
        \ 'comments': []
        \ }
  let path = ''
  for directory in directories
    let path .= directory
    try
      call mkdir(path)
    catch
    endtry
  endfor

  call writefile([json_encode(pending_pr_comments_data)], path . '/data', '')
endfu

fu! critiq#review#local_pending_review_exists(pr)
  return filereadable(s:local_pending_review_dir(a:pr) . '/data')
endfu

fu! critiq#review#get_local_pending_review(pr)
  try 
    return json_decode(readfile(s:local_pending_review_dir(a:pr) . '/data')[0])
  catch
    throw 'Could not read local pending review file'
  endtry
endfu

fu! critiq#review#request_pending_review(pr)
  let local_pending_review_file_path = s:local_pending_review_dir(a:pr) . '/data'
  if filereadable(local_pending_review_file_path)
    echoerr 'Local pending pull request review already exist.'
  else
    echo 'Requested Local Pending Changes' 
    call s:write_review_file(a:pr)
  endif
endfu

fu! critiq#review#add_comment_to_local_pending_review(pr, line_diff, body)
  let data = {
        \'path': a:line_diff['file'],
        \'position': a:line_diff['file_index'],
        \'body': a:body
        \ }
  let local_pending_review_file = json_decode(readfile(s:local_pending_review_dir(a:pr) . '/data')[0])
  call add(local_pending_review_file.comments, data)
  echo local_pending_review_file
  call writefile([json_encode(local_pending_review_file)], s:local_pending_review_dir(a:pr) . '/data')
endfu

