# playercenter-backend

A backend to gather and store data about players.

## API

### Retrieve information about a player

#### Request

**GET** ``/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player you want to retrieve information about.

##### Body

Empty.

#### Response

##### Body

JSON encoded object like this:

```javascript
{
  "uuid": "some-uuid",
  "venue": {
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

All information under the ``venue`` is present for each venue this player is playing a Quarter Spiral game on.

### List player's friends

#### Request

**GET** ``/:UUID:/friends``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the player who's friends you want to retrieve.

##### Body

Empty.

#### Response

##### Body

JSON encoded object mapping a friend's UUID to an object of player info (see *Retrieve information about a player*) like this:

```javascript
{
  "some-uuid":  {
    "uuid": "some-uuid",
    "venue": {
      "facebook": {
        "id": "1234",
        "name": "The Peter"
      },
      "spiral-galaxy": {
        "id": "87233",
        "name": "Peter Smith"
      }
    }
  },
  "other-uuid": {
    …
  }
}
```

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
