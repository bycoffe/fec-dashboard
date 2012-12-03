filings = null
appSettings = null
title = ''
windowFocused = true

committeeTypes =
  'C': 'Communication Cost'
  'D': 'Delegate'
  'E': 'Electioneering Communication'
  'H': 'House'
  'I': 'Independent Expenditor (Person or Group)'
  'N': 'PAC - Nonqualified'
  'O': 'Independent Expenditure-Only (Super PAC)'
  'P': 'Presidential'
  'Q': 'PAC - Qualified'
  'S': 'Senate'
  'U': 'Single Candidate Independent Expenditure'
  'X': 'Party Nonqualified'
  'Y': 'Party Qualified'
  'Z': 'National Party Nonfederal Account'


class Filing extends Backbone.Model

  initialize: ->
    @set committee_id: @get('fec_committee_id')
    @set full_committee_type: committeeTypes[@get('committee_type')]
    @set raised: @format_amount(@get('receipts_total'))
    @set spent: @format_amount(@get('disbursements_total'))
    @set view: new FilingView(model: @)
    unless @get('initialLoad')
      @alert()

  format_amount: (n) ->
    return unless n
    n += ''
    x = n.split('.')
    x1 = x[0]
    x2 = if x.length > 1 then '.' + x[1] else ''
    regex = /(\d+)(\d{3})/
    while regex.test(x1)
        x1 = x1.replace(regex, '$1' + ',' + '$2')
    x1 + x2


  alert: ->
    return unless appSettings.get('showNotifications')
    unless window.webkitNotifications
      console.log 'No support for desktop notifications'

    if window.webkitNotifications.checkPermission() > 0
      @requestPermission(@alert)

    icon = 'http://query.nictusa.com/images/fec1.gif'
    amendment = ''
    if @get('is_amendment')
      amendment = ' [amendment] '
    popup = window.webkitNotifications.createNotification icon, @get('committee_name'), "#{@get('report_title')}#{amendment}"
    popup.show()

  requestPermission: (callback) ->
    window.webkitNotifications.requestPermission callback


class Filings extends Backbone.Collection

  model: Filing

  getFilings: (initialLoad=false, date=null) ->
    return unless appSettings.get('apikey').length > 0

    if date
      month = date.getMonth()
      if month < 12 then month += 1 else month = 1
      url = "http://api.nytimes.com/svc/elections/us/v3/finances/2012/filings/#{date.getFullYear()}/#{month}/#{date.getDate()}.json"
    else
      url = 'http://api.nytimes.com/svc/elections/us/v3/finances/2012/filings.json'

    newFilings = false
    $.ajax
      dataType: 'jsonp'
      url: url
      data:
        'api-key': $("#apikey").val()
      success: (data) =>
        unless data.status is 'OK'
          throw new Error "Error. Status: #{data.status}"
        for result in data.results
          unless @get(result.fec_uri)
            result = _(result).extend
              id: result.fec_uri
              timestamp: new Date()
              initialLoad: initialLoad
            @add result
            newFilings = true

    if newFilings
      unless initialLoad
        unless windowFocused
          $("title").html "[*] #{title}"
    setTimeout((=> @getFilings()), 900000)


class FilingView extends Backbone.View

  tagName: 'tr'

  initialize: ->
    @template = _.template $("#filing-row-template").html()
    @mobileTemplate = _.template $("#mobile-filing-row-template").html()
    @render()

  render: ->
    $(@el).html @template(@model.toJSON())
    if @model.get('initialLoad')
      $("#filings tbody").append @el
    else
      $("#filings tbody").prepend @el

    mobileEl = @$el.clone()
    $(mobileEl).html @mobileTemplate(@model.toJSON())
    if @model.get('initialLoad')
      $("#mobile-filings tbody").append mobileEl
    else
      $("#mobile-filings tbody").prepend mobileEl


class Settings extends Backbone.Model

  defaults:
    apikey: ''
    showNotifications: false

  initialize: ->
    args = @getQs()
    if args.apikey?
      $("#apikey").val args.apikey
      @set apikey: args.apikey

    @set showNotifications: args.notify is 'true'

  getQs: ->
    qs = window.location.search.substring 1
    pairs = qs.split '&'
    args = {}
    for pair in pairs
      [k, v] = pair.split '='
      args[k] = unescape v
    args

  save: (callback) ->
    @set
      apikey: $("#apikey").val()
      showNotifications: $("#show-notifications").attr('checked') is 'checked'

    if @get('apikey').length > 0
      window.location.search = "?apikey=#{@get('apikey')}&notify=#{@get('showNotifications')}"

    filings.getFilings(true)


class SaveSettingsView extends Backbone.View

  el: "#save-settings"

  events:
    'click': 'handleClick'

  handleClick: (e) ->
    e.preventDefault()
    $("#settings").modal('hide')


$(document).ready ->
  title = $("title").html()

  filings = new Filings()
  appSettings = new Settings()

  filings.getFilings(true)

  if appSettings.get('apikey')
    $("#filing-content").show()
  else
    $("#welcome").show()

  $("#settings").on 'shown', ->
    saveSettingsView = new SaveSettingsView()
    if appSettings.get('showNotifications') is true
      $("#show-notifications").attr('checked', 'checked')

  $("#settings").on 'hide', ->
    appSettings.save()

  $("#update-now").bind 'click', ->
    filings.getFilings()

  $("#welcome-enter-api-key").bind 'click', ->
    $("#settings").modal('show')

  $(window).blur ->
    windowFocused = false

  $(window).focus ->
    windowFocused = true

  $(window).bind 'focus', ->
    $("title").html title

  today = new Date()
  month = today.getMonth()
  if month < 12 then month += 1 else month = 1
  $("#datepicker-input").val "#{today.getFullYear()}-#{month}-#{today.getDate()}"

  $("#datepicker").datepicker(
    format: 'yyyy-mm-dd'
    endDate: new Date()
    autoclose: true
  ).on('changeDate', (ev) ->
    date = new Date(ev.date.valueOf())
    date.setDate date.getDate()+1
    $("#filings tbody tr").remove()
    filings.reset()
    filings.getFilings(true, date)
  )
