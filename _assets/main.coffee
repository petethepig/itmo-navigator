


DirectionView = Backbone.View.extend({
  initialize: ->

    @$el = $("<div class='direction' ><div class='icon' ></div><div class='length'></div><div class='label'></div></div>")
    @el = @$el.get(0)

  render: () ->
    if(@model)
      @$el.children(".icon").addClass(@model.icon)
      @$el.children(".length").text(Math.round(@model.length/1042*153) + " м") if @model.length
      @$el.show().children(".label").text(@model.name)
    else
      @$el.hide()
    this
})


SearchResultView = Backbone.View.extend({
  initialize: ->

    @$el = $("<a href='javascript:void(0);' class='search-result' ></a>")
    @el = @$el.get(0)

  initEvents: ->
    that = this
    clickHandler = (e)->
      e.preventDefault()
      that.trigger "click", that
      $("#from>input, #to>input").blur()
    Hammer(@el).on "tap", clickHandler
  update: () ->
    if(@model)
      @$el.show().html(@model.string)
    else
      @$el.hide()
})


MainView = Backbone.View.extend({
  
  matches : []
  locations : {from:null, to: null}
  criteries : {from:"", to:""}
  focused : null
  searchResultViews : []
  directionViews : []
  
  fuzzy_options: 
    pre: '<strong>'
    post: '</strong>'
    extract: (e) -> 
      e.name

  initialize: ->
    Hammer($(".clear-btn").get(0)).on "tap", @clearHandler.bind(this)
    
    for i in [0...20] by 1
      view = new SearchResultView()
      $("#search-results").append(view.$el)
      view.initEvents()
      view.on "click", @clickHandler.bind(this)
      @searchResultViews[i] = view
    @update()
    
  
  clickHandler: (view) ->
    @locations[@focused] = view.model.original
    $("#"+@focused+">input").val(view.model.original.name)
    @focused = null
    $(".input-wrapper").removeClass "expand fade-out"
    $(".clear-btn").removeClass("fade-in")
    @update()

  events:
    "focus #from>input, #to>input":"focusHandler"
    "blur #from>input, #to>input":"blurHandler"
    "keyup #from>input, #to>input":"keypressHandler"
  focusHandler: (e) ->
    e.target.value = ""
    pairs = {
      "from":"#to"
      "to":"#from"
    }
    $p = $(e.target).parent()
    id = $p.attr("id")
    $p.addClass "expand"
    $(pairs[id]).addClass("fade-out")
    $(".clear-btn").addClass("fade-in")
    @focused = id
    @update()
  clearHandler: (e) ->
    console.log @focused
    if @focused
      $el = $("#"+@focused+">input").val("").focus()
      @criteries[@focused] = ""
      @update()
      $el.focus()
  blurHandler: (e) ->
  keypressHandler: (e) ->
    that = this
    setTimeout ->
      that.update()
    , 1
  update: ->
    @criteries[@focused] = $("#"+@focused+">input").val()
    $("#search-results").toggle @focused != null
    $("#directions").toggle((@focused == null) && !!@locations.from && !!@locations.to)

    that = this
    results = fuzzy.filter(@criteries[@.focused] || "", @model.locations, @fuzzy_options)
    @matches = results.map (el) -> 
      el
    $(".nothing-found").toggle @matches.length <= 0
    i = 0
    for view in @searchResultViews
      match = @matches[i]
      view.model = match
      view.update()
      i++
    this

    if !!@locations.from && !!@locations.to

      route = @model.getRoute @locations.from, @locations.to
      console.log route
      
      $("#directions").empty()

      if route.length > 0
        prev_direction = null
        for direction in route
          view = new DirectionView(model:direction)
          $("#directions").append view.el
          view.render()
          prev_direction = direction
      else
        $("#directions").append $("<div class='nothing-found'>Путь не найден</div>")

})




Graph = (data) ->


  locationsForId = {}
  relativesFor = {}
  lengthFor = {}
  iconFor = {}

  opposite = {
    "R":"L"
    "L":"R"
    "A":"A"
  }

  connect = (a,b,c) ->
    relativesFor[a] ||= []
    relativesFor[b] ||= []
    relativesFor[a].push b
    relativesFor[b].push a
    x = vertices[a].x-vertices[b].x
    y = (vertices[a].y-vertices[b].y)*2
    lengthFor[a+b] = lengthFor[b+a] = Math.sqrt(x*x + y*y) 
    iconFor[a+b] = c || "A" 
    iconFor[b+a] = opposite[iconFor[a+b]]



  vertices = data.vertices
  locations = data.locations
  for edge in data.edges
    connect.apply this, edge

  _(locations).each (l) ->
    locationsForId[l.at] ||= []
    locationsForId[l.at].push l

  window.lengthFor = lengthFor

  _getRoute = (from_loc, to_loc) -> # Dijkstra's algorithm
    from = from_loc.at
    to = to_loc.at
    queue = [ from ]
    checked = []
    relations = {} # child : father
    result = []
    lengths = {}
    lengths[from] = 0
    while queue.length > 0
      currentLocation = queue.shift()
      checked.push currentLocation
      if(to == currentLocation)
        tmpLoc = to
        while tmpLoc
          result.unshift tmpLoc
          tmpLoc = relations[tmpLoc]
        break
      if relativesFor[currentLocation]
        for relative in relativesFor[currentLocation]
          if !_.contains(checked, relative)
            l = lengths[currentLocation] + lengthFor[currentLocation+relative]
            if !relations[relations] || relations[relative] > l
              relations[relative] = currentLocation
              l = lengths[relative] = lengths[currentLocation] + lengthFor[currentLocation+relative]
              index = 0
              for i of queue
                if l > lengths[queue[i]]
                  index = i + 1
                else
                  break
              if(!_.contains(queue, relative))
                queue.splice index, 0, relative

    prev_location = null
    result = result.map (id) ->
      parent = relations[id]
      location = locationsForId[id][0]
      length = lengthFor[parent+id]
      prev_location = location
      {
        icon: iconFor[parent+id]
        name: location.name
        length: length
      }
    if result.length > 0
      result[0].name = from_loc.name
      result[result.length - 1].name = to_loc.name
      result[0].icon = "S"
      result[result.length - 1].icon += " F"
    result

  return {
    locations: locations
    getRoute: _getRoute
  }




$ ->
  
  $.ajax
    url: "./data.json"
    success: (data)->
      graph = new Graph(data)
      $("header").show()  
      mainView = new MainView(el:$("#wrapper"), model: graph)
      graph.getRoute(graph.locations[0], graph.locations[15])

