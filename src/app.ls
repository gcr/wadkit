THREE = require 'three'

wad-parser = require './data/wad-parser.ls'
map-model = require './data/map-model.ls'
require './editor/editor-context.ls'
require './editor/file-drag-and-drop.ls'
Db = require './editor/db.ls'
tex3d = require './3d/tex-3d.ls'
Vue = require 'vue/dist/vue.js'
VueRouter = require 'vue-router/dist/vue-router.js'
Vue.use VueRouter


router = new VueRouter do

  routes:
    * path: '/'
      component:
        data: -> message: ""
        template: '''
          <div class='fullsize'>
            <h4 v-if="message" style="margin: auto;" class="editor-panel">{{message}}</h4>
            <wad-upload-zone @file="haveFile"/>
          </div>
          '''
        methods:
          have-file: (file)->>
            result = await Db.save-file file
            @$router.push "/#{file.name}"



    * path: '/:file'
      props: true
      component:
        props: ['file']
        template: '''
        <div class='fullsize'>
          <h4>Map browser: {{file}}</h4>
          <br />
          <ul v-if="loaded">
              <li v-for="lump in wad.lumps">{{lump.name}}</li>
              <li v-for="lump,v of pk3">{{lump}}</li>
          </ul>
        </div>
        '''
        data: ->
          loaded: false
          wad: null
          pk3: null
        watch: file:
          immediate: true
          handler: (fname)->>
            console.log "hi"
            @loaded = false
            console.log "loading..."
            file = await Db.load-file fname
            if not file
              @$router.push '/'
              throw Error "File not in cache: #{fname}"

            console.log file
            buf = await file.array-buffer!
            console.log buf
            if file.name.to-lower-case!.ends-with "wad"
              @wad = await wad-parser.wad-parse buf
              @loaded = true
              console.log @wad
            else if file.name.to-lower-case!.ends-with "pk3"
              @pk3 = await wad-parser.pk3-parse buf
              @loaded = true
            else
              throw new Error "Unknown file type: #{file.name}"



new Vue do
  router: router
  el: '#app'
  template: '''
  <router-view />
  '''

-> new Vue do
  el: '#app'
  template: '''
  <div class='fullsize'>
  </div>
  '''




-> new Vue do
  el: '#app'
  template: '''
    <div class='fullsize'>

      <h4 v-if="loadingMessage" style="margin: auto;" class="editor-panel">
        {{loadingMessage}}
        <progress v-if="progress !== null" max="100" :value="Math.floor(100 * progress)" />
      </h4>

      <wad-upload-zone v-if="waitingForFile" @file="haveFile"/>

      <map-editor
        :mapModel="mapModel"
        :texMan="texMan"
        v-if="mapModel != null"
      />

    </div>
  '''
  data: ->
    waiting-for-file: false
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
    #fetch-remote-file = (url) ->>
    #    response = await fetch url
    #    buf = await response.arrayBuffer()
    #    return buf

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

    @waiting-for-file = true
    @loading-message = null


  methods:
    have-file: (buf, name) ->
      @waiting-for-file = false

      MAP = "MAP01"
      #@loading-message = "Loading #{name}..."
      #buf <~ fetch-remote-file "https://cdn.glitch.com/4653581b-1ac7-413c-8c15-b8bf8cbfcf56%2FMAP01.wad?v=1584718762039" .then
      #buf <~ fetch-remote-file "assets/#{MAP}.wad" .then
      @loading-message = "Parsing #{name}..."
      <~ set-timeout _, 10
      wad <~ wad-parser.wad-parse buf .then
      map <~ wad-parser.wad-read-map wad, MAP .then
      @loading-message = "Loading geometry..."
      <~ set-timeout _, 10
      @map-model = new map-model.MapModel wad, map
      @loading-message = ""

      window.map-model = @map-model
