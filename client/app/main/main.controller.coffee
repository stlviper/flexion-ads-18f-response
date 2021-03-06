'use strict'

angular.module('gsfFdaApp').controller 'MainCtrl', ($scope, $http, usSpinnerService) ->
  $scope.adverseReactions = []

  $scope.xAxisTickFormatFunction = ->
     (d) ->
        dateString = d.replace(/(\d{4})(\d{2})/g, '$2/01/$1')
        d3.time.format('%b %Y')(new Date(dateString))

  $scope.xFunction = ->
    (d) ->
      d[0]

  format = d3.format(',.0f')
  $scope.valueFormatFunction = ->
    (d) ->
      format(d)

  $scope.reset = ->
    $scope.adverseReactions = []
    $scope.brandname = ''
    $scope.searchname = ''
    usSpinnerService.stop 'spinner-1'


  $scope.startSpin = ->
    usSpinnerService.spin 'spinner-1'

  colorCategory = d3.scale.category20()
  $scope.colorFunction = ->
    (d, i) ->
      colorCategory(i)

  $scope.search = (brandname) ->
    $scope.adverseReactions = []
    $scope.errorMessage = ''
    #todo move to a filter service
    if brandname
      $scope.searchname = brandname
      if brandname.term
        brandname = brandname.term

      query = search:
        fields: [
          {
            field: 'brand_name'
            terms: [ { term: brandname } ]
          },
          {
            field: 'serious'
            terms: [ { term: '1' } ]
            isAnd: true
          },
          {
            field: 'receivedate'
            terms: [ { term: '[20140101+TO+20150101]' } ]
            isAnd: true
          }
        ]
        count: field: 'receivedate'

      #TODO move to a service - ideally a adverseReaction model
      queryString = JSON.stringify query
      $http.get("/api/epi-search/?search=#{window.btoa queryString}")
        .success (adverseReactions) ->
          usSpinnerService.stop 'spinner-1'
          $scope.adverseReactions = adverseReactions.results

          groupedByDateData = _.groupBy adverseReactions.results, (result) ->
            result.time.substring(0,6)

          aggregateByDate = _.map groupedByDateData, (result, time) ->
            time: time
            count: _.reduce result, (m, x) ->
              m + x.count
            , 0

          data = [{key:"Serious Reactions", values: [] }]
          for result in aggregateByDate
            valuesArray = []
            valuesArray.push result.time
            valuesArray.push result.count
            data[0].values.push valuesArray

          $scope.adverseReactions = data
      .error (data, status, header, config) ->
        usSpinnerService.stop 'spinner-1'
        if data.error.code
          $scope.errorMessage = data.error.message
        else
          $scope.errorMessage = "Sorry! We didn't find any data with that query. Please revise your search and try again."
    else
      usSpinnerService.stop 'spinner-1' #nothing to search for

  #start typeahead TODO move to a service
  query =
    search:
      fields: [
        {
          field: "patient.drug.openfda.pharm_class_epc"
          terms: [
            {term: "anti-epileptic"}
            {term: "agent"}

          ]
        },
        {
          field: "receivedate",
          terms: [
            {term: "[20140101+TO+20150101]"}
          ],
          isAnd: true
        }
      ],
      count:
        field: "patient.drug.medicinalproduct"

  engine = new Bloodhound
    datumTokenizer: (d) -> Bloodhound.tokenizers.whitespace d.term
    queryTokenizer: Bloodhound.tokenizers.whitespace
    prefetch:
      url: "/api/epi-search/?search=#{window.btoa(JSON.stringify query)}"
      filter: (result) ->
        result.results

    limit: 10
    minLength: 2

  engine.clearPrefetchCache();
  engine.initialize()

  $scope.pharmaNames =
    displayKey: 'term'
    source: engine.ttAdapter()

  $scope.pharmaOptions =
    highlight: true
