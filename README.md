# React Native Search Api module

The `SearchApi` module gives you a general React Native interface to interact with the iOS Search API, Core Spotlight.

For more information about iOS Search APIs, see [https://developer.apple.com/ios/search/](https://developer.apple.com/ios/search/).

## Installation

### Automatic part

1. `npm install react-native-search-api --save`
1. `react-native link`

### Manual part

To the top of your `AppDelegate.m` add the following line:
```objc
#import "RCTSearchApiManager.h"
```

In your AppDelegate implementation add the following:
```objc
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    return [RCTSearchApiManager application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}
```

## Usage

Subscribe to the search item open events in your components like this:
```js
componentDidMount() {
    <...>
    SearchApi.addOnSpotlightItemOpenEventListener(this.handleOnSpotlightItemOpenEventListener);
    SearchApi.addOnAppHistoryItemOpenEventListener(this.handleOnAppHistoryItemOpenEventListener);
}
```

To prevent memory leaks don't forget to unsubscribe:
```js
componentWillUnmount() {
    <...>
    SearchApi.removeOnSpotlightItemOpenEventListener(this.handleOnSpotlightItemOpenEventListener);
    SearchApi.removeOnAppHistoryItemOpenEventListener(this.handleOnAppHistoryItemOpenEventListener)
}
```

Generally you should be interested whether the app was started using the search, therefore consider using
the following two methods:
```js
// For the spotlight item:
SearchApi.getInitialSpotlightItem().then(result => {
    if (result) {
        console.log('Started with a spotlight item!')
    }
})
// For the app history item:
SearchApi.getInitialAppHistoryItem().then(result => {
    if (result) {
        console.log('Started with an app history item!')
    }
})
```

In order to create a new spotlight item, use `indexSpotlightItem` or `indexSpotlightItems`:
```js
SearchApi.indexSpotlightItem(item).then(result => {
    console.log('Success');
}).catch(err => {
    console.log('Error: ' + err);
});
```

To add new items to the app history, use `createUserActivity`:
```js
SearchApi.indexAppHistoryItem(item).then(result => {
    console.log('Success');
    that.setState({labelText: 'Success'});
}).catch(err => {
    console.log('Error: ' + err);
    that.setState({labelText: ('Error: ' + err)});
});
```

The parameters, that items may specify are listed below:

## Search item keys

Dictionaries, passed to create spotlight and app history items have some common
and some specific keys, here is the list of all possible keys.

### Common keys

##### `title`: string
Title of the item. Required for both item types.

##### `contentDescription`: string
Description of the item. Optional.

##### `keywords`: Array<string>
An array of keywords, assigned to the search item. Optional.

##### `thumbnail`: string|int|object
Thumbnail to be presented in the search results. The same format as `source` in
the `Image` component. Optional.

Examples:
```js
var localItem = {
  <...>,
  thumbnail: require('/react-native/img/favicon.png')
};
var remoteItem = {
  <...>,
  thumbnail: {uri: 'https://facebook.github.io/react-native/docs/assets/favicon.png'}
};
```

Please refer to [documentation](https://facebook.github.io/react-native/docs/image.html) for more details.

### Spotlight-specific keys

##### `uniqueIdentifier`: string
The unique identifier of the spotlight item, passed later on during
the item opening event. Required.

##### `domain`: string
The domain for the spotlight item. Optional.

### App history-specific keys

##### `userInfo`: Object
A dictionary, passed later on during the item opening event. Required.

##### `eligibleForPublicIndexing`: boolean
A flag, that when set to `true` allows to add the item to the public index.
Optional.

##### `expirationDate`: Date
Expiration date of the user activity item. Optional.

##### `webpageURL`: string
URL of the page, representing the same content on the app's website.

## Credits
[© 2017 PresenceKit by Ombori AB](https://ombori.com/)
