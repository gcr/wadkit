THREE = require 'three'

wad-parser = require './data/wad-parser.ls'
map-model = require './data/map-model.ls'
require './editor/editor-context.ls'
tex3d = require './3d/tex-3d.ls'
Vue = require 'vue/dist/vue.js'

new Vue do
  el: '#app'
  template: '''
    <div class='fullsize'>
      <h1 v-if="status">{{status}}</h1>
      <map-editor
        :mapModel="mapModel"
        :texMan="texMan"
        v-if="mapModel != null"
      />
    </div>
  '''
  data: ->
    status: "Wait..."
    map-model: null
    tex-man: null
  mounted: ->
    fetch-remote-file = (url) ->>
        response = await fetch url
        buf = await response.arrayBuffer()
        return buf

    # Load textures
    console.time 'pk3-parse-and-tex-ingest'
    @tex-man = new tex3d.TextureManager!

    # SRB2 2.2
    #console.time '- fetch'
    #buf <- fetch-remote-file "assets/srb2-2.2.pk3" .then
    #console.time-end '- fetch'
    #console.time '- pk3 parse'
    #gfx-wad <- wad-parser.pk3-parse buf .then
    #console.time-end '- pk3 parse'
    #console.time '- tex ingest pk3'
    #<- tex-man.ingest-pk3 gfx-wad .then
    #console.time-end '- tex ingest pk3'

    # SRB2Kart
    @status = "Loading SRB2Kart: srb2.srb..."
    buf <~ fetch-remote-file "assets/srb2kart/srb2.srb" .then
    @status = "Parsing SRB2Kart: srb2.srb..."
    <~ set-timeout _, 10
    gfx-wad <~ wad-parser.wad-parse buf .then
    @status = "Adding textures from SRB2Kart: srb2.srb..."
    <~ set-timeout _, 10
    <~ @tex-man.ingest-wad gfx-wad .then
    @status = "Loading SRB2Kart: textures.kart..."
    <~ set-timeout _, 10
    buf <~ fetch-remote-file "assets/srb2kart/textures.kart" .then
    @status = "Parsing SRB2Kart: textures.kart..."
    <~ set-timeout _, 10
    gfx-wad <~ wad-parser.wad-parse buf .then
    @status = "Adding textures from SRB2Kart: textures.kart..."
    <~ set-timeout _, 10
    <~ @tex-man.ingest-wad gfx-wad .then
    console.time-end 'pk3-parse-and-tex-ingest'

    MAP = "MAPAA"
    @status = "Loading #{MAP}.wad..."
    buf <~ fetch-remote-file "assets/#{MAP}.wad" .then
    @status = "Parsing #{MAP}.wad..."
    <~ set-timeout _, 10
    wad <~ wad-parser.wad-parse buf .then
    map <~ wad-parser.wad-read-map wad, MAP .then
    @status = "Loading geometry..."
    <~ set-timeout _, 10
    @map-model = new map-model.MapModel wad, map
    @status = ""



    # Picking
    #
    #vertex-shader = """
    #    attribute float texIndex;
    #    attribute vec4 texBounds;
    #    varying float vTexIndex;
    #    varying vec2 vUv;
    #    varying vec4 vTexBounds;
    #    varying vec3 vposition;
    #    void main () {
    #      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    #      vposition = position;
    #    }
    #"""
    #fragment-shader = """
    #    varying vec3 vposition;
    #    void main() {
    #        gl_FragColor = vec4(vposition, 1);
    #    }
    #"""
    #pick-mat = new THREE.ShaderMaterial vertex-shader: vertex-shader, fragment-shader: fragment-shader
    #
    ## set up the geometry
    #geo = map3d.map-mesh.geometry
    #mesh = new THREE.Mesh geo, pick-mat
    #mesh.rotation.copy map3d.rotation
    #mesh.scale.copy map3d.scale
    #mesh.position.copy map3d.position
    #
    ## set up the scene?
    #picking-scene = with new THREE.Scene!
    #  ..background = new THREE.Color(0)
    #  ..add mesh
    #
    ## render to a custom render target
    #picking-texture = new THREE.WebGLRenderTarget 1, 1, do
    #  type: THREE.FloatType
    #  format: THREE.RGBAFormat
    #pixel-buffer = new Float32Array(4)
    #pixel-ratio = renderer.get-pixel-ratio!
    #pick = (x,y)->
    #  camera.set-view-offset(
    #        renderer.getContext().drawingBufferWidth,   # full width
    #        renderer.getContext().drawingBufferHeight,  # full top
    #        x * pixelRatio,             # rect x
    #        y * pixelRatio,             # rect y
    #        1,                                          # rect width
    #        1,                                          # rect height
    #  );
    #  # render the scene
    #  renderer.set-render-target picking-texture
    #  renderer.render picking-scene, camera
    #  renderer.set-render-target null
    #  camera.clear-view-offset!
    #  renderer.read-render-target-pixels picking-texture, 0,0,1,1, pixel-buffer
    #
    #renderer.domElement.add-event-listener 'mousemove', (e)->
    #  pick? e.x,e.y
