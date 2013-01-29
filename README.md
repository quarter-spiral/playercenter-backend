# playercenter-backend

A backend to gather and store data about players.

## API

### Retrieve public information about a player

Does not need any authentication. The response from this endpoint is very close to the non-public information about players (**GET** ``/:UUID:``) . It omits any sensible data (e.g. venue specific IDs), though.

#### Request

**GET** ``/public/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player you want to retrieve information about.

##### Body

Empty.

#### Response

##### Body

JSON encoded object like this:

```javascript
{
  "uuid": "some-uuid",
  "venues": {
    "facebook": {
      "name": "The Peter"
    },
    "spiral-galaxy": {
      "name": "Peter Smith"
    }
  }
}
```

All information under the ``venues`` is present for each venue this player is playing a Quarter Spiral game on.

### List player's friends public information

This endpoint does not need any authentication and resembles closely the ``List player's friends`` endpoint (**GET** to ``/:UUID:/friends``) which needs to be called authenticated over OAuth. This endpoint will only return publicly available information about friends.

#### Request

**GET** ``/public/:UUID:/friends``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's friends you want to retrieve.

##### Body

Empty

#### Response

Please note that the list of friends always includes the requester itself, too.

##### Body

JSON encoded object mapping a friend's UUID to an object of player info (see *Retrieve public information about a player*) like this:

```javascript
{
  "some-uuid":  {
    "uuid": "some-uuid",
    "facebook": {
      "name": "The Peter"
    },
    "spiral-galaxy": {
      "name": "Peter Smith"
    }
  },
  "other-uuid": {
    …
  }
}
```

### List the games a player plays

This endpoint does not need authentication.

#### Request

**GET** to ``/public/:UUID:/games``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's games are going to be retrieved

##### Body

JSON encoded Object with additional options:

* **venue**: If set only games that the player play's on the given venue will be listed

#### Response

##### Body

JSON encoded object of games in the way the ``devcenter-backend`` public API returns game lists.

### Retrieve information about a player

#### Request

**GET** ``/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player you want to retrieve information about.

##### Body

Empty.

#### Response

##### Body

JSON encoded object like this:

```javascript
{
  "uuid": "some-uuid",
  "venues": {
    "facebook": {
      "id": "1234",
      "name": "The Peter"
    },
    "spiral-galaxy": {
      "id": "87233",
      "name": "Peter Smith"
    }
  }
}
```

All information under the ``venues`` is present for each venue this player is playing a Quarter Spiral game on.

### List player's friends

#### Request

**GET** ``/:UUID:/friends``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's friends you want to retrieve.

##### Body

JSON encoded object with further options:

* **game**: If present only displays friends who play the game with the given UUID
* **meta**: An array of keys of player meta data that is added to each friend. This parameter requires the game parameter to be set as the meta data is stored per player/game pair.

#### Response

Please note that the list of friends always includes the requester itself, too.

##### Body

JSON encoded object mapping a friend's UUID to an object of player info (see *Retrieve information about a player*) like this:

```javascript
{
  "some-uuid":  {
    "uuid": "some-uuid",
    "facebook": {
      "id": "1234",
      "name": "The Peter"
    },
    "spiral-galaxy": {
      "id": "87233",
      "name": "Peter Smith"
    }
  },
  "other-uuid": {
    …
  }
}
```

If the ``meta`` parameter is set the meta results will be added as another venue called ``meta`` like this:

```javascript
{
  "some-uuid":  {
    "uuid": "some-uuid",
    "facebook": {
      "id": "1234",
      "name": "The Peter"
    },
    "spiral-galaxy": {
      "id": "87233",
      "name": "Peter Smith"
    },
    "meta": {
      "highScore": 100,
      "lastLevel": "Good Chamber"
    }
  },
  "other-uuid": {
    …
  }
}
```

### [DEPRECATED] List the games a player plays

#### Request

**GET** to ``/:UUID:/games``

This endpoint is deprecated in favor of the public endpoint at ``/public/:UUID:/games`` which behaves the same but does not require authentication. You must use the public endpoint instead.

### List the games the friends of a player play

#### Request

**GET** to ``/:UUID:/games/friends``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's games are going to be retrieved

##### Body

JSON encoded Object with additional options:

* **venue**: If set only games that the player play's on the given venue will be listed

#### Response

##### Body

JSON encoded object of games in the way the ``devcenter-backend`` public API returns game lists.

### Update a users friends

#### Request

**PUT** to ``/:UUID:/friends/:VENUE:``

This will add all friends that are not already in the system.

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's friends are going to be updated
- **VENUE** [REQUIRED]: The venue on which the friendships are etablished

##### Body

A JSON encoded object of venue identities like this:

```javascript
{
  "friends": [
    {"venue-id": "23423", "name": "Peter Smith"},
    {"venue-id": "89482", "name": "Sam Jackson"}
  ]
}
```

#### Response

Returns status 200 on success.

##### Body

Empty.

### Retrieve a user's avatar on a given venue

This request does not require any authentication.

#### Request

**GET** to ``/:UUID:/avatars/:VENUE:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's avatar is going to be retrieved
- **VENUE** [REQUIRED]: The venue of which the user's avatar is going to be retrieved from

##### Body

Empty.

#### Response

This might return the avatar image directly (HTTP status ``200``) or a ``302`` HTTP redirect to the actual avatar image.

### Register a user as a player of a game

#### Request

**POST** to ``/:PLAYER-UUID:/games/:GAME-UUID:/:VENUE:``

##### Parameters

- **PLAYER-UUID** [REQUIRED]: The UUID of the player who is playing the game
- **GAME-UUID** [REQUIRED]: The UUID of a game the player is playing
- **VENUE** [REQUIRED]: The venue on which the player is playing

##### Body

Empty.

#### Response

Returns status code 201 if the player was registered as a new player of the game, 304 if the player already plays the game on that venue. If the player already plays the game but not on that venue a 200 status code is returned instead. The body is empty.


### Set player's game meta data

#### Request

**PUT** to ``/:PLAYER-UUID:/games/:GAME-UUID:/meta-data/:KEY:``

##### Parameters

- **PLAYER-UUID** [REQUIRED]: The UUID of the player who you want to set the meta data for
- **GAME-UUID** [REQUIRED]: The UUID of a game the you want to set the meta data for
- **KEY** [OPTIONAL] A key name in the metadata object. If set only this key will be updated.

##### Body

JSON encoded object of meta data under a ``meta`` key like this:

```javascript
{
  "meta": {
    "highscore": 100,
    "levelsCompleted": "[1,2,3]",
    "playedTutorial": true
  }
}
```

Only numbers, boolean values and strings are accepted as meta data values. If you need more complex types as arrays and objects you can always encode them as strings, e.g. in JSON notation.

If the ``KEY`` parameter is set you still provide an object as the body. Nonetheless, the request will only change the specified key of the metadata. E.g. if you only want to change the high score to ``112``, you can issue a **PUT** to ``/:PLAYER-UUID:/games/:GAME-UUID:/meta-data/highscore`` with a JSON encoded body of this object:

```javascript
{
  "meta": {
    "highscore": 110
  }
}
```

#### Response

Returns status code 200 if the data was set successfully. Returns status code 415 if wrong data types are used in the meta data.

##### Body

JSON encoded meta data object of the changed meta data. This always returns the whole meta data object even when a ``KEY`` parameter was present.

Example:

```javascript
{
  "meta": {
    "highscore": 110,
    "levelsCompleted": "[1,2,3]",
    "playedTutorial": true
  }
}
```

### Retrieve player's game meta data

#### Request

**GET** to ``/:PLAYER-UUID:/games/:GAME-UUID:/meta-data``

##### Parameters

- **PLAYER-UUID** [REQUIRED]: The UUID of the player who you want to get the meta data for
- **GAME-UUID** [REQUIRED]: The UUID of a game the you want to set get meta data for

##### Body

Empty.

#### Response

JSON encoded meta data object.

Example:

```javascript
{
  "meta": {
    "highscore": 110,
    "levelsCompleted": "[1,2,3]",
    "playedTutorial": true
  }
}
```