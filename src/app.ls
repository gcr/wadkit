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


MAP = "MAP04"

buf <- fetch-remote-file "assets/#{MAP}.wad" .then
wad <- wad-parser.wad-parse buf .then
map <- wad-parser.wad-read-map wad, MAP .then

console.time "map model"
model = new map-model.MapModel map
console.time-end "map model"

# Load textures
console.time 'pk3-parse-and-tex-ingest'
tex-man = new tex3d.TextureManager!
# SRB2 2.2
console.time '- fetch'
buf <- fetch-remote-file "assets/srb2-2.2.pk3" .then
console.time-end '- fetch'
console.time '- pk3 parse'
gfx-wad <- wad-parser.pk3-parse buf .then
console.time-end '- pk3 parse'
console.time '- tex ingest pk3'
<- tex-man.ingest-pk3 gfx-wad .then
console.time-end '- tex ingest pk3'

# SRB2Kart
#buf <- fetch-remote-file "assets/srb2kart/srb2.srb" .then
#gfx-wad <- wad-parser.wad-parse buf .then
#<- tex-man.ingest-wad gfx-wad .then
#buf <- fetch-remote-file "assets/srb2kart/textures.kart" .then
#gfx-wad <- wad-parser.wad-parse buf .then
#<- tex-man.ingest-wad gfx-wad .then

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
