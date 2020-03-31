Vue = require 'vue/dist/vue.js'
THREE = require 'three'
CameraControls = require './camera-controls.ls'
grid2d = require './grid-2d.ls'
m3d = require '../3d/map-3d.ls'
picker = require './picker.ls'

Vue.component 'map-editor' do
  # Represents a map editor component.
  template: '''
    <div class='map-editor fullsize'>
      <context-stack keyRef='canvas' :editor='this' ref='stack'/>
      <canvas ref='canvas' tabindex=0
              @mousemove="canvasMouseMove"/>
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
    picker: null
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

    @picker = new picker.Picker {@map3d, @camera, @renderer}


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
    canvas-mouse-move: (e)->
      @picker.maybe-pick e.x, e.y


Vue.component 'context-stack' do
  # Manages things like keyboard dispatch, the
  # UI showing editing modes left to right, ...
  #
  # Fundamentally, a 'context' is:
  # - a list of widgets, which themselves may be
  #   components;
  template: '''
  <nav>
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

  data: -> do
    contexts: ['root-context']

  mounted: ->
    console.log "Adding event listener", @, @element
    @element.add-event-listener 'keydown', @on-key-down, false

  methods:
    on-key-down: (e)->
      console.log "key down: #{e.key}", e
      if e.key == 'Escape'
        @pop-context!
      else
        result-context = null
        thunk = ->
        for context-name in @contexts
          ctx = @$refs[context-name][0]
          console.log ctx, ctx.keymap
          if ctx.keymap? and e.key of ctx.keymap
            thunk = ctx.keymap[e.key].thunk
            result-context = context-name
        @pop-to result-context
        thunk!
    push-context: (context-name) ->
      @contexts.push context-name
    pop-to: (name)->
      while name and @contexts.length > 1 and @contexts[*-1] != name
        @contexts.pop!
    pop-context: ->
        if @contexts.length > 1
          @contexts.pop!


Vue.component 'root-context' do
  template: '''
    <ul class='editor-panel'>
      <li><label class='narrow'><i>S</i>ector</label></li>
      <li><label class='narrow'><i>L</i>inedef</label></li>
      <li><label class='narrow'><i>D</i>ebug</label></li>
    </ul>
  '''
  props: ['editor']
  computed:
    keymap: ->
      s:
        name: 'Sector context'
        thunk: ~> @editor.stack.push-context 'sector-context'
      l:
        name: 'Linedef context'
        thunk: ~> @editor.stack.push-context 'linedef-context'
      d:
        name: 'Debug gun'
        thunk: ~> @editor.stack.push-context 'debug-gun'
  methods:
    sector-context: ->
      console.log "Sector context, from", @
      @editor.stack.push-context 'sector-context'
    linedef-context: ->
      console.log "Linedef context, from", @
      @editor.stack.push-context 'linedef-context'

Vue.component 'sector-context' do
  template: '''
  <h1>Sector Context!</h1>
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

Vue.component 'linedef-context' do
  template: '''
  <h1>Linedef Context!</h1>
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

Vue.component 'debug-gun' do
  props: ['editor']
  template: '''
  <div class='editor-panel'>
    <picker :editor='editor' @pick='pick' />
    <h1>DEBUG GUN</h1>
    <ul>
      <li><label>Position:</label> {{Math.floor(x)}}, {{Math.floor(y)}}, {{Math.floor(z)}}</li>
      <li><label>ID:</label> {{id}}</li>
      <li><label>Type:</label> {{type}}</li>
      <li v-if="isLinedef">
        <label>Front textures:</label><br />
        {{linedef.frontSidedef.lowerTex}},
        {{linedef.frontSidedef.middleTex}},
        {{linedef.frontSidedef.upperTex}}
      </li>
      <li v-if="isLinedef && linedef.backSidedef">
        <label>Back textures:</label><br />
        {{linedef.backSidedef.lowerTex}},
        {{linedef.backSidedef.middleTex}},
        {{linedef.backSidedef.upperTex}}
      </li>
    </ul>
  </div>
  '''
  data: -> x: 0, y: 0, z:0, id:0, type:0
  computed:
    is-sector: -> @type in [2,4]
    is-linedef: -> @type in [1]
    sector: -> @editor.map-model.sectors[@id]
    linedef: -> @editor.map-model.linedefs[@id]
    keymap: ->
      h:
        name: "Putz with height"
        thunk: ~>
          if @type == 2
            sector = @editor.map-model.sectors[@id]
            console.log "Sector:", sector
            @editor.map3d.update-sector sector, floor-height: sector.floor-height+16
            console.log "Sector:", sector
  methods:
    pick: ({@x,@y,@z, @id,@type}) ->
