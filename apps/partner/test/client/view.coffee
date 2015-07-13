benv = require 'benv'
Backbone = require 'backbone'
sinon = require 'sinon'
CurrentUser = require '../../../../models/current_user.coffee'
Artworks = require '../../../../collections/artworks.coffee'
Partner = require '../../../../models/partner.coffee'
Profile = require '../../../../models/profile.coffee'
_ = require 'underscore'
{ resolve } = require 'path'
{ fabricate } = require 'antigravity'

describe 'PartnerView', ->

  before (done) ->
    benv.setup =>
      benv.expose { $: benv.require 'jquery' }
      Backbone.$ = $
      done()

  after ->
    benv.teardown()

  describe 'when setting up tabs', ->

    beforeEach (done) ->
      sinon.stub Backbone, 'sync'
      benv.render resolve(__dirname, '../../templates/index.jade'), {
        profile: new Profile fabricate 'partner_profile'
        sd: { PROFILE: fabricate 'partner_profile' }
        asset: (->)
        params: {}
      }, =>
        PartnerView = mod = benv.requireWithJadeify(
          (resolve __dirname, '../../client/view'), ['tablistTemplate']
        )

        @profile = new Profile fabricate 'partner_profile'
        @partner = new Partner @profile.get('owner')
        @tablistTemplate = sinon.stub()
        @CollectionView = sinon.stub()
        @CollectionView.returns @CollectionView
        mod.__set__ 'tablistTemplate', @tablistTemplate
        mod.__set__ 'sectionToView', { collection: @CollectionView }

        @view = new PartnerView
          model: @profile
          partner: @partner
          el: $ 'body'
        @view.partner.set 'displayable_shows_count', 1
        done()

    afterEach ->
      Backbone.sync.restore()

    describe '#getDisplayableSections', ->

      it 'filters and gets the sections needed in the tabs', ->
        sections = @view.getDisplayableSections @view.getSections()
        sections.should.eql ['shows', 'articles', 'about']

    describe '#initializeTablistAndContent', ->

      it 'renders correct tabs', ->
        sinon.stub @view.partner, "fetch", (options) -> options?.success?()
        @view.initializeTablistAndContent()
        _.last(@tablistTemplate.args)[0].profile.get('id').should.equal @profile.get('id')
        _.last(@tablistTemplate.args)[0].sections.should.eql ['shows', 'articles', 'about']

    describe '#renderSection', ->

      it 'uses the right default params to initialize the view', ->
        @view.renderSection('collection')
        @CollectionView.args[0][0].isForSale.should.not.be.ok()

      it 'overrides default params when passing in extra params', ->
        @view.renderSection('collection', { isForSale: true, feature: 'giant' })
        @CollectionView.args[0][0].isForSale.should.be.ok()
        @CollectionView.args[0][0].feature.should.equal 'giant'
