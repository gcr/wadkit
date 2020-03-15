THREE = require 'three'
require! 'fs'

wad-parser = require './data/wad-parser.ls'
map-model = require './data/map-model.ls'

grid2d = require './editor/grid-2d.ls'
CameraControls = require './editor/camera-controls.ls'

tex3d = require './3d/tex-3d.ls'
m3d = require './3d/map-3d.ls'

fetch-remote-file = (url) ->>
    response = await fetch url
    buf = await response.arrayBuffer()
    return buf


# Make renderer
scene = new THREE.Scene()
camera = new THREE.PerspectiveCamera( 90, window.innerWidth / window.innerHeight, 0.1, 1000 )
renderer = new THREE.WebGLRenderer() #antialias: true)
document.body.appendChild( renderer.domElement )
renderer.domElement.tabIndex = 0

camera.position.z = 4
camera.up.set 0,0,1

resize-renderer-to-display-size = ->
  canvas = renderer.domElement
  w = canvas.clientWidth   # * window.devicePixelRatio
  h = canvas.clientHeight  # * window.devicePixelRatio
  needResize = canvas.width !== w or canvas.height !== h
  if needResize then renderer.setSize w, h, false
  return needResize

#renderer.domElement.add-event-listener "click", ->
#  document.body.request-fullscreen!


MAP = "MAPAA"

buf <- fetch-remote-file "assets/#{MAP}.wad" .then
wad <- wad-parser.wad-parse buf .then
map <- wad-parser.wad-read-map wad, MAP .then

model = new map-model.MapModel map

# Load textures
console.time 'pk3-parse-and-tex-ingest'
tex-man = new tex3d.TextureManager!
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
buf <- fetch-remote-file "assets/srb2kart/srb2.srb" .then
gfx-wad <- wad-parser.wad-parse buf .then
<- tex-man.ingest-wad gfx-wad .then
buf <- fetch-remote-file "assets/srb2kart/textures.kart" .then
gfx-wad <- wad-parser.wad-parse buf .then
<- tex-man.ingest-wad gfx-wad .then

console.time-end 'pk3-parse-and-tex-ingest'

#console.log "GFZWALL:", tex-man.get 'GFZWALL'
#tex-man.get-shader-material!

# Construct geometry
console.time 'map3d'
map3d = new m3d.Map3dObj model, tex-man
map3d.scale.set 0.01,0.01,0.01
console.time-end 'map3d'

scene.add map3d
window.model = model
window.map3d = map3d
window.tex = tex-man
controls = new CameraControls.OrbitalPanCameraControls camera, renderer.domElement
#OrbitControls = require('three-orbit-controls')(THREE)
#controls = new OrbitControls(camera, renderer.domElement)
#controls.panning-mode = 0 # horizontal panning

grid = new grid2d.MapGrid2D model, controls
grid.scale.set 0.01,0.01,0.01
scene.add grid

s = {alpha: 0.0}
toggle-edit = (e)->
  if e.key == 'e' and not e.repeat
    s.alpha = 1 - s.alpha
renderer.domElement.add-event-listener 'keydown', toggle-edit, false
animate = ->
  canvas = renderer.domElement
  if resize-renderer-to-display-size!
    camera.aspect = canvas.clientWidth / canvas.clientHeight
    camera.updateProjectionMatrix!

  controls.update!
  grid.update!

  #alpha += 0.01
  #map3d.set-intensity 0.5 + Math.sin(alpha)/2.0
  #grid.set-intensity 1.0 - (0.5 + Math.sin(alpha)/2.0)
  map3d.set-intensity 1-s.alpha
  grid.set-intensity s.alpha

  request-animation-frame animate
  renderer.render scene, camera
animate!


vertex-shader = """
    attribute float texIndex;
    attribute vec4 texBounds;
    varying float vTexIndex;
    varying vec2 vUv;
    varying vec4 vTexBounds;
    varying vec3 vposition;
    void main () {
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      vposition = position;
    }
"""
fragment-shader = """
    varying vec3 vposition;
    void main() {
        gl_FragColor = vec4(vposition, 1);
    }
"""
pick-mat = new THREE.ShaderMaterial vertex-shader: vertex-shader, fragment-shader: fragment-shader

# set up the geometry
geo = map3d.map-mesh.geometry
mesh = new THREE.Mesh geo, pick-mat
mesh.rotation.copy map3d.rotation
mesh.scale.copy map3d.scale
mesh.position.copy map3d.position

# set up the scene?
picking-scene = with new THREE.Scene!
  ..background = new THREE.Color(0)
  ..add mesh

# render to a custom render target
picking-texture = new THREE.WebGLRenderTarget 1, 1, do
  type: THREE.FloatType
  format: THREE.RGBAFormat
pixel-buffer = new Float32Array(4)
pixel-ratio = renderer.get-pixel-ratio!
pick = (x,y)->
  camera.set-view-offset(
        renderer.getContext().drawingBufferWidth,   # full width
        renderer.getContext().drawingBufferHeight,  # full top
        x * pixelRatio,             # rect x
        y * pixelRatio,             # rect y
        1,                                          # rect width
        1,                                          # rect height
  );
  # render the scene
  renderer.set-render-target picking-texture
  renderer.render picking-scene, camera
  renderer.set-render-target null
  camera.clear-view-offset!
  renderer.read-render-target-pixels picking-texture, 0,0,1,1, pixel-buffer

renderer.domElement.add-event-listener 'mousemove', (e)->
  pick? e.x,e.y
