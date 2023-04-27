(function (module) {
  var createFrontendAuth = (function() {
    const auth0Client = new Auth0Client({
      domain: 'dev-zyzedo2i.us.auth0.com',
      client_id: 'hI5UPIC4K7P2tU87tBaOvjCnFQUL9J4a'
    });
    const properties = {};
    async function signin() {
      await auth0Client.loginWithPopup();
      var user = await auth0Client.getUser({
        fields: ['nickname', 'user_id', 'app_metadata', 'user_metadata', 'name', 'picture'],
        includeFields: true
      });
      this.properties.currentUser = user;
      document.getElementById('is_signedin').checked = true;
    }
    async function signout() {
      await auth0Client.logout();
      document.getElementById('is_signedin').checked = false;
    }
    return Object.freeze({
      auth0Client,
      signin,
      signout,
      properties
    });
  });
  module.FrontendAuth = createFrontendAuth();
})(window);
