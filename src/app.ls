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
      <h4 v-if="loadingMessage" style="margin: auto;" class="editor-panel">
        {{loadingMessage}}
        <progress v-if="progress !== null" max="100" :value="Math.floor(100 * progress)" />
      </h4>
      <map-editor
        :mapModel="mapModel"
        :texMan="texMan"
        v-if="mapModel != null"
      />
    </div>
  '''
  data: ->
    loading-message: "Wait..."
    map-model: null
    tex-man: null
    progress: null

  mounted: ->
    fetch-remote-file = (url) ~>>
        response = await fetch url
        content-length = response.headers.get 'Content-length'
        received = 0
        reader = response.body.get-reader!
        chunks = []
        while true
          {done, value} = await reader.read!
          if done then break
          received += value.length
          @progress = received / content-length
          chunks.push value
        buf = new Uint8Array received
        @progress = null
        pos = 0
        for c in chunks
          buf.set c, pos
          pos += c.length
        return buf

    # Load textures
    console.time 'pk3-parse-and-tex-ingest'
    @tex-man = new tex3d.TextureManager!

    ## SRB2 2.2
    @loading-message = "Loading SRB2: srb2-2.2.pk3..."
    buf <~ fetch-remote-file "https://cdn.glitch.com/4653581b-1ac7-413c-8c15-b8bf8cbfcf56%2Fsrb2-2.2.pk3?v=1584718779583" .then
    @loading-message = "Parsing SRB2: srb2-2.2.pk3..."
    <~ set-timeout _, 10
    gfx-wad <~ wad-parser.pk3-parse buf .then
    @loading-message = "Adding textures from SRB2: srb2-2.2.pk3..."
    <~ set-timeout _, 10
    <~ @tex-man.ingest-pk3 gfx-wad .then


    # SRB2Kart
    #@loading-message = "Loading SRB2Kart: srb2.srb..."
    #buf <~ fetch-remote-file "assets/srb2kart/srb2.srb" .then
    #@loading-message = "Parsing SRB2Kart: srb2.srb..."
    #<~ set-timeout _, 10
    #gfx-wad <~ wad-parser.wad-parse buf .then
    #@loading-message = "Adding textures from SRB2Kart: srb2.srb..."
    #<~ set-timeout _, 10
    #<~ @tex-man.ingest-wad gfx-wad .then
    #@loading-message = "Loading SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #buf <~ fetch-remote-file "assets/srb2kart/textures.kart" .then
    #@loading-message = "Parsing SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #gfx-wad <~ wad-parser.wad-parse buf .then
    #@loading-message = "Adding textures from SRB2Kart: textures.kart..."
    #<~ set-timeout _, 10
    #<~ @tex-man.ingest-wad gfx-wad .then
    #console.time-end 'pk3-parse-and-tex-ingest'

    MAP = "MAP01"
    @loading-message = "Loading #{MAP}.wad..."
    #buf <~ fetch-remote-file "https://cdn.glitch.com/4653581b-1ac7-413c-8c15-b8bf8cbfcf56%2FMAP01.wad?v=1584718762039" .then
    buf <~ fetch-remote-file "assets/#{MAP}.wad" .then
    @loading-message = "Parsing #{MAP}.wad..."
    <~ set-timeout _, 10
    wad <~ wad-parser.wad-parse buf .then
    map <~ wad-parser.wad-read-map wad, MAP .then
    @loading-message = "Loading geometry..."
    <~ set-timeout _, 10
    @map-model = new map-model.MapModel wad, map
    @loading-message = ""

    window.map-model = @map-model
