Vue = require 'vue/dist/vue.js'
THREE = require 'three'
CameraControls = require './camera-controls.ls'
grid2d = require './grid-2d.ls'
m3d = require '../3d/map-3d.ls'

Vue.component 'map-editor' do
  # Represents a map editor component.
  template: '''
    <div class='map-editor fullsize'>
      <context-stack keyRef='canvas' :editor='this' ref='stack'/>
      <canvas ref='canvas' tabindex=0 />
    </div>
  '''
  props: ['map-model', 'tex-man']
  data: -> do
    scene: null
    camera: null
    renderer: null
    map3d: null
    controls: null
    grid: null
  computed:
    canvas: -> @$refs.canvas
    stack: -> @$refs.stack
  mounted: ->
    @scene = new THREE.Scene!
    @camera = new THREE.PerspectiveCamera 90, window.innerWidth / window.innerHeight, 0.1, 1000
    @camera.up.set 0,0,1
    # TODO: after first render
    @renderer = new THREE.WebGLRenderer canvas: @canvas
    @map3d = new m3d.Map3dObj @map-model, @tex-man
    @controls = new CameraControls.OrbitalPanCameraControls @camera, @canvas
    @grid = new grid2d.MapGrid2D @map-model, @controls


    @scene.add @map3d
    @map3d.scale.set 0.01,0.01,0.01
    @grid.scale.set 0.01,0.01,0.01
    @animate!

  methods:
    reset-size: ->
      w = @canvas.clientWidth   # * window.devicePixelRatio
      h = @canvas.clientHeight  # * window.devicePixelRatio
      needResize = @canvas.width !== w or @canvas.height !== h
      if needResize then @renderer.setSize w, h, false
      return needResize
    animate: ->
      request-animation-frame ~>
        if @reset-size!
          @camera.aspect = @canvas.clientWidth / @canvas.clientHeight
          @camera.updateProjectionMatrix!

        @controls.update!
        @grid.update!

        @renderer.render @scene, @camera

        # next frame?
        @animate!


Vue.component 'context-stack' do
  # Manages things like keyboard dispatch, the
  # UI showing editing modes left to right, ...
  #
  # Fundamentally, a 'context' is:
  # - a list of widgets, which themselves may be
  #   components;
  template: '''
  <nav :style='style'>
    <component v-for="ctx in contexts"
                 :is="ctx"
                 :editor='editor'
                 :ref='ctx'
    />
  </nav>
  '''
  props: ['editor', 'keyRef']
  computed:
    element: -> @$parent.$refs[@keyRef]
    style: ->
      position: "absolute"
      display: "flex"
      flex-flow: "row nowrap"
      align-items: "start"
      margin: "1em"

  data: -> do
    contexts: ['root-context']

  mounted: ->
    console.log "Adding event listener", @, @element
    @element.add-event-listener 'keydown', @on-key-down, false

  methods:
    on-key-down: (e)->
      console.log "key down: #{e.key}", e
      if e.key == 'Escape'
        if @contexts.length > 1
          @contexts.pop!
      else
        thunk = ->
        for ctx in @contexts
          ctx = @$refs[ctx][0]
          console.log ctx, ctx.keymap
          if ctx.keymap? and e.key of ctx.keymap
            thunk = ctx.keymap[e.key]
        thunk!
    push-context: (context-name) ->
      @contexts.push context-name


Vue.component 'root-context' do
  template: '''
    <ul :style='style'>
    ROOT CONTEXT
    <br>
    <div>Foobar?</div>
    </ul>
  '''
  props: ['editor']
  computed:
    keymap: ->
      s: ~> @sector-mode!
      l: ~> @linedef-mode!
    style: ->
      margin: 0
      padding: "1em"
      background: "rgba(0,0,0,0.5)"
      border-radius: "0.5em"
  methods:
    sector-mode: ->
      console.log "Sector mode, from", @
      @editor.stack.push-context 'sector-mode'
    linedef-mode: ->
      console.log "Linedef mode, from", @
      @editor.stack.push-context 'linedef-mode'

Vue.component 'sector-mode' do
  template: '''
  <h1>Sector Mode!</h1>
  '''
  props: ['editor']
  mounted: ->
    @editor.map3d.set-intensity do
      wireframe: 1.0
      floor: 1.0
      ceiling: 1.0
      linedef: 0.2
      fof-floor: 1.0
      fof-ceiling: 1.0
      fof-linedef: 0.2
  destroyed: ->
    @editor.map3d.set-intensity!

Vue.component 'linedef-mode' do
  template: '''
  <h1>Linedef Mode!</h1>
  '''
  props: ['editor']
  mounted: ->
    @editor.map3d.set-intensity do
      wireframe: 1.0
      floor: 0.2
      ceiling: 0.2
      linedef: 1.0
      fof-floor: 0.2
      fof-ceiling: 0.2
      fof-linedef: 1.0
  destroyed: ->
    @editor.map3d.set-intensity!
