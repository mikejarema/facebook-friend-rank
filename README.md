# Facebook Friend Rank

This project does one thing: it attempts to rank a person's Facebook friend list from "best friend" to "worst friend".

It is a stand-alone ruby-based web service, built on top of [Goliath](http://goliath.io), with the following goals:

* Deployable to heroku straight from the repository

* Requires only an access token and user ID (both found in the JS SDK FB._authResponse object), returns only a hash of 
  IDs to scores to be used in your sorting algorithm


## Philosophy

It is impossible to absolutely rank your friends (let alone EVERYONE'S friends) without regard for
context, cultural nuance, and ultimately the fidelity of an online persona with that of the real world.

This project attempts to do so anyways.

It may or may not provide a "reasonable" result anytime you need to rank a list of friends.


## Ranking Strategy

*Requires the read_stream permission.*

Currently the ranking strategy is crude. It scans ~500 of a person's most 
recent feed items, tallies up the occurences of each unique friend ID, and
returns this as the sorting data hash.

Ideally this evolves to into a adaptive solution which:

1. Determines which permissions are available and picks a strategy optimized
   for accuracy and speed-of-execution based on available data.

2. Offers biasing facilities, eg. to influence rank based on context or
   personal affinities defined by the calling app (this is a pipedream).


## Usage

Once deployed (see deployment notes below) this web service has a single JSONP call of interest at the root URL.

http://facebook-friend-rank.herokuapp.com/?token=[fb-access-token]&id=[current-user-id]&async=[true/false]

Currently the access token requires the read-stream permission.

Because Friend Rank will take awhile to run, there are two modes of operation: asynchronous (progressive) and synchronous.

The returned hash may not contain entries for all friends, assume a zero value for these friends (they're the "worst").

### Asynchronous Usage (Default)

When the JSONP is made, Friend Rank returns immediately with an nearly empty hash. This initial call triggers
the long-running ranking algorithm to start running in the background.

    {
      "data":     {},
      "progress": 0.0
    }

As it runs it builds up progressively more accurate and comprehensive results, which are found at the same endpoint.
So subsequent calls will see more ranking data to work with:

    {
      "data":     {"123451":9,"123452":99,"123453":1,"123454":1,"123455":1,"123456":1,"123457":1,"123458":2,"123459":2},
      "progress": 0.2
    }

When "progress" reaches 1.0, the background process is complete.

The caller of this endpoint may choose to act on the friend rank data at any point, for example to sort
friends early on in the process, or wait until the algorithm is complete before doing anything. Frankly speaking, 
Friend Rank is a heuristic which attempts to improve accuracy with more computation. Early results should have
reasonable fidelity to those determined by a full run of the ranking algorithm.

This endpoint is fast, so it may be polled frequently.

Results are cached for an hour.

### Synchronous Usage

By setting async=false in the call, you're instructing Friend Rank to return only when it is finished computing
results in their entirety.

Note: an application which mixes asynchronous and synchronous calls may exhibit funny behaviour as a common cache is used.


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

* Error handling

* Specs

* Different ranking strategies based on varying levels of permissions provided by the access token


## Acknowledgements

* Thanks to [Ilya Grigorik](http://igvita.com) and his original team at [Postrank](http://postrank.com) 
  for their phenomenal contributions to the Ruby & Event Machine open source communities, particularly 
  [Goliath](http://goliath.io) and [EM::Synchrony](https://github.com/igrigorik/em-synchrony).

* Additional thanks to Ilya for his post: 
  [0-60: Deploying Goliath on Heroku Cedar](http://www.igvita.com/2011/06/02/0-60-deploying-goliath-on-heroku-cedar/)

* Thanks to Jeremy Keeshin for his post and bookmarklet: 
  [Who Does Facebook Think You Are Searching For?](http://thekeesh.com/2011/08/who-does-facebook-think-you-are-searching-for/)


## License & Notes

The MIT License - Copyright (c) 2012 [Mike Jarema](http://mikejarema.com)
