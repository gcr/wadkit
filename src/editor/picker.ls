THREE = require 'three'
Vue = require 'vue/dist/vue.js'

vertex-shader = """
    attribute float attrType;
    attribute float attrId;
    varying float vType;
    varying float vId;
    varying vec3 vposition;
    void main () {
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      vType = attrType;
      vId = attrId;
      vposition = position;
    }
"""
fragment-shader = """
    varying float vType;
    varying float vId;
    varying vec3 vposition;
    void main() {
        gl_FragColor = vec4(vposition, vId*64.0 + vType);
    }
"""

export class Picker
  ({@map3d, @camera, @renderer})->
    # Picking
    #
    @pick-mat = new THREE.ShaderMaterial vertex-shader: vertex-shader, fragment-shader: fragment-shader

    # set up the geometry
    @mesh = new THREE.Mesh @map3d.map-mesh.geometry, @pick-mat

    # set up the scene?
    @picking-scene = with new THREE.Scene!
      ..background = new THREE.Color(0)
      ..add @mesh

    # render to a custom render target
    @picking-texture = new THREE.WebGLRenderTarget 1, 1, do
      type: THREE.FloatType
      format: THREE.RGBAFormat
    @pixel-buffer = new Float32Array(4)
    @pixel-ratio = @renderer.get-pixel-ratio!

    @callbacks = {}
    @n-callbacks = 0

  maybe-pick: (x,y)->
    if @n-callbacks == 0
      console.log "Skipping picking..."
      return
    console.log "PICKING"
    @mesh.rotation.copy @map3d.rotation
    @mesh.scale.copy @map3d.scale
    @mesh.position.copy @map3d.position
    pixelRatio = @renderer.getPixelRatio!
    @camera.set-view-offset(
          @renderer.getContext().drawingBufferWidth,   # full width
          @renderer.getContext().drawingBufferHeight,  # full top
          x * pixelRatio,                             # rect x
          y * pixelRatio,                             # rect y
          1,                                          # rect width
          1,                                          # rect height
    )
    # render the scene
    @renderer.set-render-target @picking-texture
    @renderer.render @picking-scene, @camera
    @renderer.set-render-target null
    @camera.clear-view-offset!
    @renderer.read-render-target-pixels @picking-texture, 0,0,1,1, @pixel-buffer

    for k,v of @callbacks
      v do
        x: @pixel-buffer[0]
        y: @pixel-buffer[1]
        z: @pixel-buffer[2]
        type: Math.floor(@pixel-buffer[3] % 32)
        id: Math.floor(@pixel-buffer[3] / 64)

  on-pick: (cb)->
    key = Math.random!
    @callbacks[key] = cb
    @n-callbacks++
    return ~>
      delete @callbacks[key]
      @n-callbacks--

Vue.component 'picker' do
  template: '''<div style="display: none;"></div>'''
  props: ['editor']
  data: ->
    destroy-picker-key: null
  mounted: ->
    @destroy-picker-key = @editor.picker.on-pick (e)~> @$emit 'pick', e
  destroyed: ->
    @destroy-picker-key!
    console.log "Active pickers:", @editor.picker


  #renderer.domElement.add-event-listener 'mousemove', (e)-> pick? e.x,e.y
