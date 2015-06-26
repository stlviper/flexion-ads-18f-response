'use strict'

angular.module 'gsfFdaApp'
  .filter 'titleCase', ->
    (input) ->
      input = input or ''
      if input.term
        input = input.term
      input.replace(/\w\S*/g, (txt) ->
        txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())
