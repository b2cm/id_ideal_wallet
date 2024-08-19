# iOS specifics

## Install Instructions

After cloning you need to start the app once from the command line in order for flutter to install its dependencies locally. Open the xcode workspace file. Make sure you only have one instance of xcode open before running the following in the repositories root directory:

```cmd
flutter run
```

Note: NFC capability is only included in the paid plan for apple developer teams.

## Structure

Everything runs from the AppDelegate. As soon as the screen is loaded the method channels to flutter are initialized. There are 3 methods we can expect: 1. connectSdk 2. disconnectSdk 3. sendCommand

We let the ios wrapper for the AusweisApp sdk handle most the work, we just need to decode and encode the correct datatypes. The method channel sendCommand channel will give us a json string which we decode. It has a root object "cmd" which includes the instruction type. We simply switch on that and call the corresponding function in the wrapper. Some cases require parsing data types. That should be much less once Android implements the wrapper as well.

On the flipp side we implementa callback handler required by the ausweis wrapper. You can find that in CallBackManager.swift. When those callbacks are called can be found in the Governikus documentation or as a comment in the wrapper code itself. All we do here is to again match some datatypes. Only noteworthy here is that we need to call interrupt when we want the nfc scanner dialog to disappear, for example when the user is required some input(pin). Since the dialog is hardcoded into the nfc lib from apple there is no other way around that. Eventchannels are used to send the requested information back to flutter.