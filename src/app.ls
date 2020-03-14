THREE = require 'three'
require! './wad-parser.ls'
grid2d = require './grid-2d.ls'
tex3d = require './tex-3d.ls'
require! 'fs'

fetch-remote-file = (url) ->>
    response = await fetch url
    buf = await response.arrayBuffer()
    return buf

m3d = require './map-3d.ls'

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
console.time "parse WAD"
wad <- wad-parser.wad-parse buf .then
console.time-end "parse WAD"
console.time "read wad info"
map <- wad-parser.wad-read-map wad, MAP .then
console.time-end "read wad info"

require! './map-model.ls'
console.time "map model"
model = new map-model.MapModel map
console.time-end "map model"

# Load textures
console.time 'pk3-parse'

tex-man = new tex3d.TextureManager!
# SRB2 2.2
buf <- fetch-remote-file "assets/srb2-2.2.pk3" .then
gfx-wad <- wad-parser.pk3-parse buf .then
<- tex-man.ingest-pk3 gfx-wad .then

# SRB2Kart
#buf <- fetch-remote-file "assets/srb2kart/srb2.srb" .then
#gfx-wad <- wad-parser.wad-parse buf .then
#<- tex-man.ingest-wad gfx-wad .then
#buf <- fetch-remote-file "assets/srb2kart/textures.kart" .then
#gfx-wad <- wad-parser.wad-parse buf .then
#<- tex-man.ingest-wad gfx-wad .then


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
CameraControls = require './camera-controls.ls'
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
