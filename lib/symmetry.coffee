require './core_ext'


find_missing_tests = (changed_files) ->
  extract = (filename) ->
    /^(app|spec)(\/(?:contexts|models|services)\/(?:.*\.rb))/.exec(filename) || []

  normalize = (filename) ->
    filename.replace '_spec.rb', '.rb'

  app_files  = []
  spec_files = []

  for file in changed_files
    [_, type, cropped] = extract file.filename

    switch type
      when 'app' then app_files.push cropped
      when 'spec' then spec_files.push normalize(cropped)

  app_files.difference(spec_files).map((i) -> "app#{i}")


find_problems = (commits, ignores = []) ->
  get_symmetry = (message) ->
    ///^\[
      s([\w,]+)
      (?:\||:)
      m([\w,]+)
      (?:\||:)
      r([\w,]+)
      \]///i.exec(message.toLowerCase()) || []

  is_merge = (message) ->
    /^Merge (pull request #|remote-tracking branch '|branch ')/.test message

  is_revert = (message) ->
    /^Revert "/.test message

  overall = []
  ls = rs = 0
  for commit in commits
    commit.problems = []
    message = commit.commit.message
    continue  if is_merge(message) or is_revert(message) or 'symmetry badge' in ignores

    [_, s, m, r] = get_symmetry message
    unless s? and m? and r?
      commit.problems.push "No symmetry badge found."
      continue

    ls += 1         if s is 'l'
    rs += s.length  if /r+/.test s

    commit.problems.push "Manual testing was postponed"          if m is 'l'
    commit.problems.push "Commit wasn't reviewed by its author"  if r is 'l'

  if ls > rs
    overall.push "There are `#{ls}` specs postponed and only `#{rs}` specs were added later."

  [overall, commits]


format_message = (overall, commits, missings) ->
  to_list = (items) ->
    items.map((i) -> "* #{i}")

  format_commit = (message) ->
    message.replace(/[\n\r]/g, ' ').trunc(80)

  format_fname = (fname) -> "`#{fname}`"

  problematic = (commits) ->
    commits.filter((c) -> c.problems && c.problems.length > 0)

  message = []
  are_there_problems = commits.length && problematic(commits).length
  if !overall.length and !are_there_problems and !missings.length
    message.push "Good job, no problems were found in this pull request."
  else

    if overall.length
      message.push '#### Overall'
      message = message.concat overall
      message.push ''

    if are_there_problems
      message.push "#### Commits review"

      for commit in problematic(commits)
        message.push "#{commit.sha} #{format_commit commit.commit.message}"
        message = message.concat to_list(commit.problems)
        message.push ''

    if missings.length
      message.push "#### Spec-model correspondance"
      message.push "Are you sure you didn't forget to add specs for those files?  "
      message = message.concat to_list(missings.map(format_fname))
      message.push ''

  message.join("\n")


exports.find_missing_tests = find_missing_tests
exports.find_problems      = find_problems
exports.format_message     = format_message
