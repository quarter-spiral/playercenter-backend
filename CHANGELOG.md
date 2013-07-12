# 0.0.36 / Unreleased

* Fix a bug when switching to futuro

# 0.0.35 / 2013-07-12

* Moves friend updates out of the request/response cycle to allow large friend updates without timeout

# 0.0.34 / 2013-07-08

* Fixes result format when requesting public venue information as a batch for a single player

# 0.0.33 / 2013-07-08

* Adds an endpoint to retrieve public venue identity information in batches

# 0.0.32 / 2013-05-23

* Makes it possible to fake HTTP methods through a header
* Makes it possible to pass the OAuth token as a query param

# 0.0.31 / 2013-05-14

* Adds a ``crossdomain.xml``

# 0.0.30 / 2013-04-13

* Updates friends only once per day for each user on each venue

# 0.0.29 / 2013-04-02

* Adds authorization

# 0.0.28

* Fixes a cached bad response format

# 0.0.27

* Updates dependencies

# 0.0.26

* Makes meta data retrieval work again for not yet set meta data

# 0.0.25

* Adds caching to own and friend's games list

# 0.0.24

* Adds public endpoint to retrieve games a user plays
* Adds public endpoint to retrieve a user's friends

# 0.0.23

* Adds an endpoint for public player information
* Fixes documentation errors

# 0.0.22

* Fixes CORS headers

# 0.0.21

* Includes the requester into all friends lists

# 0.0.20

* Improve Newrelic instrumenting

# 0.0.19

* Adds Newrelic monitoring and ping middleware

# 0.0.18

* Adds player meta data to friend retrieval end point

# 0.0.17

* Fixes a bug saving ``false`` values in the game/player meta data

# 0.0.16

* Adds game/player metadata endpoints

# 0.0.15

* Adds CORS headers and OPTION endpoints to the API

# 0.0.14

* Adds an endpoint to list all games a player plays
* Adds an endpoint to list friends games
* Adds Thin

# 0.0.13

* Adds an endpoint to make a user a player in the QS graph

# 0.0.12

* Adds an endpoint to retrieve a player's avatar picture on a given venue

# 0.0.11

* Makes the API CORS compliant

# 0.0.10

* Eases the grape dependency

# 0.0.9

* Refactors galaxy-spiral to spiral-galaxy in the README
* Bumps auth-backend and auth-client

# 0.0.8

* Bumps graph-client to handle empty response bodies from the graph-backend without errors

# 0.0.7

* Changes the content type of the API to be UTF8 encoded
* Makes it runnable on metaserver

# 0.0.6

- Loads graph-client to make it work on heroku

# 0.0.5

- Adds config.ru to really make this run on heroku

# 0.0.4

- Adds Gemfile.lock to git to make the app run on heroku

# 0.0.3

- Fixes specs to make them order agnostic
- Fixes the dependencies (pin auth-client, add graph-client)

# 0.0.2

- The beginning
