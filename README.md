# id_ideal_wallet

Wallet Application supporting W3C Verifiable Credentials and recent didcomm protocolls
to issue crednetials to the wallet and request them from the wallet.

This app is in an early stage of development

**Important Notes**
- the only implemented transport layer for didcomm messsages is xmpp. Therefore a local xmpp server is needed, e.g. [ejabberd](https://hub.docker.com/r/ejabberd/ecs)
- to access this server running on your PC from the mobile device the wallet is running on, use `adb reverse` command:
  ```
  adb reverse tcp:5222 tcp:5222
  ```
  (5222 is the standard port for xmpp-messaging)
- for now the used library to interact with the xmpp server do not allow to create new users. Therefore a standard user is used. This means: to use the wallet register this user on your xmpp-server.

  - username: testuser
  - password: passwort
  - E.g.  ejabberd docker container:
  ```
  docker exec -it ejabberd bin/ejabberdctl register testuser localhost passwort
  ```
- Documentation  (Flow charts) explaining how the wallet react on specific didcomm messsages can be found in doc folder
- the wallet was not tested on iOS
- the wallet relies heavily on a self-defined header in didcomm messages. This header is called `response_to` and is structured like a service endpoint in did documents. It specifies the service endpoint to which the response to a message should be sent back.
