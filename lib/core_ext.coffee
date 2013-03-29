Array::difference = (arr) ->
  @filter (el) ->
    arr.indexOf(el) < 0

String::trunc = (n) ->
  @substr(0, n) + (if @length > n then '...' else '')

String::strip = ->
  @replace /^\s+|\s+$/g, ''

String::lines = ->
  @split /\r?\n/
