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
