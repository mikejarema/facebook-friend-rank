# Facebook Friend Rank

This project does one thing: it attempts to rank a person's Facebook friend list from "best friend" to "worst friend".

It is a stand-alone ruby-based service, built on top of [Goliath](http://goliath.io), with the following goals:

* Deployable to heroku straight from the repository

* Requires only an access token, returns only a hash of IDs to scores to be used in your sorting algorithm


## Philosophy

It is impossible to absolutely rank your friends (let alone EVERYONE'S friends) without regard for
context, cultural nuance, and ultimately the fidelity of an online persona with that of the real world.

This project attempts to do so anyways.

It may or may not provide a "reasonable" result anytime you need to rank a list of friends.


## Usage

Once deployed (see deployment notes below) this web service has a single JSONP call of interest at the root URL.

http://facebook-friend-rank.herokuapp.com/?token=[fb-access-token]

This returns a hash of FB used IDs to a unitless score.  Use the score value to sort your friend
lists, higher score means a "better" friend.

Currently the access token requires the read-stream permission.

The returned hash may not contain entries for all friends, assume a zero value for these friends (they're the "worst").


## How To Deploy To Heroku

The following assumes you have a Heroku account in good standing, and have configured your development environment.

This repository is configured to use Memcachier out of the box. Cacheless/alternative cache deployments are not
supported yet (fork me!).
    
    $ git clone git@github.com:mikejarema/facebook-friend-rank; cd facebook-friend-rank
    $ heroku apps:create facebook-friend-rank --stack cedar --addons memcachier:25
    $ git push heroku master
    
Then visit your heroku URL, eg. http://facebook-friend-rank.herokuapp.com/demo (TODO) and/or
make calls to the JSONP endpoint (see usage notes above).


## How To Deploy Elsewhere

You're on your own here (fork me!).


## Roadmap

* Sample web app bundled with the web service

* Ensure all friends have a score in returned results

* Progressive update, crude results returned quickly with more accurate results being computed against that
  access token for later use

* Error handling

* Specs

* Different ranking strategies based on varying levels of permissions provided by the access token


## Acknowledgements

* Thanks to [Ilya Grigorik](http://igvita.com) and his original team at [Postrank](http://postrank.com) 
  for their phenomenal contributions to the Ruby & Event Machine open source communities, particularly 
  [Goliath](http://goliath.io) and [EM::Synchrony](https://github.com/igrigorik/em-synchrony).

* Additional thanks to Ilya for his post 
  [0-60: Deploying Goliath on Heroku Cedar](http://www.igvita.com/2011/06/02/0-60-deploying-goliath-on-heroku-cedar/)


## License & Notes

The MIT License - Copyright (c) 2012 [Mike Jarema](http://mikejarema.com)
