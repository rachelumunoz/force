benv = require 'benv'
sinon = require 'sinon'
Backbone = require 'backbone'
LoggedOutUser = require '../../models/logged_out_user'

describe 'LoggedOutUser', ->
  before (done) ->
    benv.setup ->
      benv.expose $: benv.require 'jquery'
      done()

  after ->
    benv.teardown()

  describe 'auth related methods', ->
    beforeEach ->
      sinon.stub(Backbone, 'sync')
        .yieldsTo 'success', user: accessToken: 'secrets'

    afterEach ->
      Backbone.sync.restore()

    describe '#login', ->
      it 'logs the user in', ->
        user = new LoggedOutUser email: 'foo@bar.com', password: 'foobar'
        user.isLoggedIn().should.be.false()
        user.login()
        Backbone.sync.args[0][0].should.equal 'create'
        Backbone.sync.args[0][2].url.should.equal '/users/sign_in'
        Backbone.sync.args[0][1].attributes.should.containEql email: 'foo@bar.com', password: 'foobar'
        user.isLoggedIn().should.be.true()

      it 'accepts options and overwrites the default success', (done) ->
        user = new LoggedOutUser email: 'foo@bar.com', name: 'Foo Bar'
        user.login success: ->
          true.should.be.true()
          done()

      it 'sets the accessToken in ajax settings', ->
        user = new LoggedOutUser email: 'foo@bar.com', password: 'foobar'
        user.login()
        $.ajaxSettings.headers['X-ACCESS-TOKEN'].should.equal 'secrets'

    describe '#signup', ->
      it 'registers the user model', ->
        user = new LoggedOutUser email: 'foo@bar.com', name: 'Foo Bar', password: 'foobar'
        user.signup()
        Backbone.sync.args[0][0].should.equal 'create'
        Backbone.sync.args[0][2].url.should.containEql '/api/v1/user'
        Backbone.sync.args[0][1].attributes
          .should.containEql name: 'Foo Bar', email: 'foo@bar.com', password: 'foobar'

      it 'accepts options and overwrites the default success', (done) ->
        user = new LoggedOutUser email: 'foo@bar.com', name: 'Foo Bar', password: 'foobar'
        user.signup success: ->
          true.should.be.true()
          done()

      it 'sets the accessToken in ajax settings', ->
        user = new LoggedOutUser email: 'foo@bar.com', name: 'Foo Bar', password: 'foobar'
        user.signup()
        $.ajaxSettings.headers['X-ACCESS-TOKEN'].should.equal 'secrets'

      it 'aliases the method as #register', ->
        LoggedOutUser::register is LoggedOutUser::signup

    describe '#forgot', ->
      it 'submits a request for a password reset', ->
        user = new LoggedOutUser email: 'foo@bar.com'
        user.forgot()
        Backbone.sync.args[0][0].should.equal 'create'
        Backbone.sync.args[0][2].url.should.containEql '/api/v1/users/send_reset_password_instructions'
        Backbone.sync.args[0][1].attributes.should.containEql email: 'foo@bar.com'

      it 'accepts options and overwrites the default success', (done) ->
        user = new LoggedOutUser email: 'foo@bar.com'
        user.forgot success: ->
          true.should.be.true()
          done()

  describe '#save', ->
    beforeEach ->
      sinon.stub Backbone, 'sync'

    afterEach ->
      Backbone.sync.restore()

    describe 'default behavior', ->
      it 'saves to the anonymous session', ->
        user = new LoggedOutUser
        user.save foo: 'bar'
        Backbone.sync.args[0][1].url().should.containEql '/api/v1/me/anonymous_session'
        Backbone.sync.args[0][1].attributes.foo.should.eql 'bar'

    describe 'behavior immediately following login', ->
      beforeEach ->
        sinon.stub(LoggedOutUser::, 'isLoggedIn').returns true

      afterEach ->
        LoggedOutUser::isLoggedIn.restore()

      it 'saves to the normal me endpoint', ->
        user = new LoggedOutUser
        user.save foo: 'bar'
        Backbone.sync.args[0][1].url().should.containEql '/api/v1/me'
        Backbone.sync.args[0][1].attributes.foo.should.eql 'bar'

  describe '#fetch', ->
    beforeEach ->
      sinon.stub Backbone, 'sync'
      @user = new LoggedOutUser email: 'cab@example.com'

    afterEach ->
      Backbone.sync.restore()

    describe 'default behavior', ->
      it 'tries to find the anonymous session on the first fetch', ->
        @user.fetch()
        Backbone.sync.args[0][2].url.should.containEql '/api/v1/me/anonymous_sessions'
        Backbone.sync.args[0][2].data.should.have.keys 'email', 'session_id'

      it 'yields to the success option and sets the attributes using the first model in the response', (done) ->
        @user.fetch success: =>
          @user.get('phone').should.equal '666-666-6666'
          done()
        Backbone.sync.args[0][2].success [
          { phone: '666-666-6666' }
          { phone: '555-555-5555' }
        ]

      it 'yields to the error option', (done) ->
        @user.fetch error: (collection, response) ->
          response.error.should.eql 'existy'
          done()
        Backbone.sync.args[0][2].error error: 'existy'

      it 'fetches the session directly once it has the ID', (done) ->
        @user.fetch success: =>
          @user.fetch success: ->
            true.should.be.true()
            done()
          Backbone.sync.args[1][1].url().should.containEql '/api/v1/me/anonymous_session/foobar'
          Backbone.sync.args[1][2].success()
        Backbone.sync.args[0][2].success [id: 'foobar']

    describe 'after login', ->
      beforeEach ->
        sinon.stub(LoggedOutUser::, 'isLoggedIn').returns true

      afterEach ->
        @user.isLoggedIn.restore()

      it 'fetches through the /me endpoint if the user is logged in', (done) ->
        @user.fetch success: =>
          @user.id.should.equal 'foobar'
          done()
        Backbone.sync.args[0][1].url().should.containEql '/api/v1/me'
        Backbone.sync.args[0][2].success id: 'foobar'
