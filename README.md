# React Native Search Api module

The `Search Api` module gives you a general React Native interface to interact with the iOS Search API.

## Installation

### Automatic part

1. `npm install react-native-search-api --save`
1. `react-native link`

### Manual part

To the top of your `AppDelegate.m` add the following line:
```
#import "RCTSearchApiManager.h"
```

In your AppDelegate implementation add the following:
```
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    return [RCTSearchApiManager application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}
```

## Usage

Subscribe to the search item open events in your components like this:
```
componentDidMount() {
    <...>
    SearchApi.addOnSpotlightItemOpenEventListener(this.handleOnSpotlightItemOpenEventListener);
    SearchApi.addOnAppHistoryItemOpenEventListener(this.handleOnAppHistoryItemOpenEventListener);
}
```

To prevent memory leaks don't forget to unsubscribe:
```
componentWillUnmount() {
    <...>
    SearchApi.removeOnSpotlightItemOpenEventListener(this.handleOnSpotlightItemOpenEventListener);
    SearchApi.removeOnAppHistoryItemOpenEventListener(this.handleOnAppHistoryItemOpenEventListener)
}
```

In order to create a new spotlight item, use `indexSpotlightItem` or `indexSpotlightItems`:
```
SearchApi.indexSpotlightItem(item).then(result => {
    console.log('Success');
}).catch(err => {
    console.log('Error: ' + err);
});
```

To add new items to the app history, use `createUserActivity`:
```
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

##### title: string
Title of the item. Required for both item types.

##### contentDescription: string
Description of the item. Optional.

##### keywords: Array<string>
An array of keywords, assigned to the search item. Optional.

##### thumbnailURL: string
URL of the thumbnail, presented in the search results. Optional.

### Spotlight-specific keys

##### uniqueIdentifier: string
The unique identifier of the spotlight item, passed later on during
the item opening event. Required.

##### domain: string
The domain for the spotlight item. Optional.

### App history-specific keys

##### userInfo: Object
A dictionary, passed later on during the item opening event. Required.

##### eligibleForPublicIndexing: boolean
A flag, that when set to `true` allows to add the item to the public index.
Optional.

##### expirationDate: Date
Expiration date of the user activity item. Optional.

##### webpageURL: string
URL of the page, representing the same content on the app's website.

## Credits
Ombori Group AB
