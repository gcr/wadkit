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
    @status = "Loading SRB2: srb2-2.2.pk3..."
    buf <~ fetch-remote-file "https://cdn.glitch.com/4653581b-1ac7-413c-8c15-b8bf8cbfcf56%2Fsrb2-2.2.pk3?v=1584718779583" .then
    @status = "Parsing SRB2: srb2-2.2.pk3..."
    <~ set-timeout _, 10
    gfx-wad <~ wad-parser.pk3-parse buf .then
    @status = "Adding textures from SRB2: srb2-2.2.pk3..."
    <~ set-timeout _, 10
    <~ @tex-man.ingest-pk3 gfx-wad .then
    

    # SRB2Kart
    #@status = "Loading SRB2Kart: srb2.srb..."
    #buf <~ fetch-remote-file "assets/srb2kart/srb2.srb" .then
    #@status = "Parsing SRB2Kart: srb2.srb..."
    #<~ set-timeout _, 10
    #gfx-wad <~ wad-parser.wad-parse buf .then
    #@status = "Adding textures from SRB2Kart: srb2.srb..."
    #<~ set-timeout _, 10
    #<~ @tex-man.ingest-wad gfx-wad .then
    #@status = "Loading SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #buf <~ fetch-remote-file "assets/srb2kart/textures.kart" .then
    #@status = "Parsing SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #gfx-wad <~ wad-parser.wad-parse buf .then
    #@status = "Adding textures from SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #<~ @tex-man.ingest-wad gfx-wad .then
    #console.time-end 'pk3-parse-and-tex-ingest'

    MAP = "MAP01"
    @status = "Loading #{MAP}.wad..."
    buf <~ fetch-remote-file "https://cdn.glitch.com/4653581b-1ac7-413c-8c15-b8bf8cbfcf56%2FMAP01.wad?v=1584718762039" .then
    @status = "Parsing #{MAP}.wad..."
    <~ set-timeout _, 10
    wad <~ wad-parser.wad-parse buf .then
    map <~ wad-parser.wad-read-map wad, MAP .then
    @status = "Loading geometry..."
    <~ set-timeout _, 10
    @map-model = new map-model.MapModel wad, map
    @status = ""
