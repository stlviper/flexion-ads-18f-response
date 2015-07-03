Promise = require 'bluebird'
AWSResource = require '../aws_resource'

module.exports = class Stack extends AWSResource
  setup: ->
    @find.apply(this, arguments).then (response) ->
      return null unless response?

  find: (stack) ->
    @log "Stack.find(#{stack.name})"

    @sdk.cloudformation.listStacks_Async().then (response) ->
      for cfStack in response.StackSummaries
        return cfStack if cfStack.StackName is stack.name
      return null

  create: (stack) ->
    @log "Stack.create(#{stack.name}) - #{stack.file.location}"
    new Promise (resolve, reject) =>
      params =
        StackName: stack.name
        OnFailure: 'ROLLBACK'
        TemplateURL: stack.file.location
        TimeoutInMinutes: 30
        Capabilities: ['CAPABILITY_IAM']

      params.Parameters = stack.params if stack.params?

      @sdk.cloudformation.createStack_Async(params).then (response) =>
        @log 'Stack created', response.StackId
        @pollStack(response.StackId).then resolve

  getLogicalResource: (stack, resourceId) ->
    params =
      StackName: stack.StackName
      LogicalResourceId: resourceId

    @sdk.cloudformation.describeStackResource_Async(params).then (response) ->
      return response.StackResourceDetail

  pollStack: (stackId, token) ->
    do (stackId, token) =>
      new Promise (resolve, reject) =>
        console.log "polling stack #{stackId} for events"
        params =
          StackName: 'stackId'
        params.NextToken = token if token?

        @sdk.cloudformation.describeStackEvents_Async(params).then (response) =>
          for evt in response.StackEvents
            console.log "#{evt.Timestamp} - #{evt.LogicalResourceId} ->\
             #{evt.ResourceStatus}"
            if (response.PhysicalResourceId is stackId)
              return resolve() if (evt.ResourceStatus.indexOf 'COMPLETE' > -1)
              return reject() if (evt.ResourceStatus.indexOf 'FAILED' > -1)

            Promise.delay(5000)
              .then => @pollStack(stackId, response.NextToken)
              .then resolve
