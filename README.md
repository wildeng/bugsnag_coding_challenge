# Bugsnag coding challenge

Object of the challenge is creating a mini crash processor.
Time needed: 7h 30mins
There are 16 Rubocop offenses that I did not correct.

## Run the project

1. Install Redis
2. Open a terminal and run ```bundle install```
3. Run Redis e.g. `redis-server /usr/local/etc/redis.conf`
4. when bundle is over run ```foreman start```   

## Project structure

The project is based on a small Sinatra app that exposes two endpoints:

1. One to collect basic stats
```
{{ host:port }}/stats/:projectId
```
  1. If the project id does not exists it replies with a 404 Not found.
  2. It no project id is passed, it replies with a 400 Bad request.
  3. If the projectId exists the endpoint tries to pull the stats from a queue named `recap:<projectId>` where those are saved as JSON. If no data is present it returns a 404 not found.


2. One to post the payloads:
```
{{ host:port }}/collect
```
  1. The endpoint replies with a 200 if a json payload is passed to it
  2. The endpoint replies with a 400 bad request if nothing is present
  3. The endpoint replies with a 500 is an error of other type happened. The error is logged.
  4. The endpoint puts the payload on a queue called `error` using lpush, which basically puts an element of the top of a list and creates the list if this does not exists.


3. A simple thread that reads the Redis `error` queue using lpop so popping out an item from the list and removing it too. The thread then instantiate a processor using the `ProcessPaylod` class and creates the stats saved in a queue called `recap:<projectId>`

4. in the `services` folder the `process_payload.rb` is the class that manages the payload parsing and creates the stats. In the same folder there's also a `redis_connector.rb` which implements a Singleton class that should have provided a single instance to connect to Redis but I wasn't able to run this properly too.

5. There's also a job folder with a `Resque` background job that I wasn't able to run properly (should have probably chosen `Sidekiq` that I know slightly better), but I left it there and the I decided to create a simple thread in the Sinatra `app.rb` file. The main idea behind this was to have `Clockwork` running a background job that should have managed the payload processing.

## Tests

The tests are implemented using Minitest and can be run using the following rake task:

```
  rake test
```

they are all in the `spec` folder and are thus divided:
1. `fixtures` is a folder where a valid and invalid json payloads are placed
2. `integration` is where the integration tests are placed. I've used `Rack::TestMethods` and `Minitest` for this task and they are all in the `error_processor_spec.rb`
2. `services` is where I placed the unit testing for the Payload Processor.
3. `spec_helper.rb` is just a simple helper for testing.

## Considerations



### Pros

1. Sinatra choice:
  1. Compared to Rails, Sinatra is lightweight and it's loading time is really small given the few dependencies that it has.
  2. It does have the bare minimum, simple routing system and the most useful components are coming out of the box
  3. Besides the result of the tech test, I've learned a few new things (eg. Sinatra) so I think this has been a proof the choice


2. Use of a simple thread
  1. Straightforward and simple to use. It starts when the application starts and dies when the application is shut down.


### Cons

1. Sinatra choice:
  1. I lost time setting up things because I never used Sinatra before, and it doesn't have the amount of guides available for Rails.
  2. When I've started choosing which gems to use, a lot of them have only Rails guides or are made only for Rails, so there's quite a lot of research work to do around it.
  2. Background jobs are not so easy to integrate, and this is why I failed on this point
  4. The Sinatra app could be improved by using better configurations and probably by using a modular approach.


2. Use of a simple thread:
  1. The thread is really simple, suitable for a small task but I do not think it properly scales, without using some thread pooling system.
  2. Background jobs are better optimised and probably a better choice in this case. Clockwork looks being a good choice, because it works with Sidekiq, Resque and other gems and uses a syntax which is similar to Cron.

### Not implemented tasks

#### Avoid projects swarming the queue

We could also use Redis for this: we could for example set a rate limit like n requests for every given minute and save the value in Redis using a key composed in the following way: `projectId:current_minute_number` eg. `1234:1` and we could set an expiring time on this eg:

|1234:0 |1234:1 |...| 1234:59|
--- | --- | --- | --- |
|2 | 11 | ... | 6|
|latest 10:02 |latest 10:03| ... | latest 11:01|
|10:00 | 10:01| ... | 10:59|

what will happen is that if we set 10 requests as a limit in any given minute, before allowing the request to be put in the queue our code should:

1. check the key given the current_minute_number, if it does not exist it creates it and set the expiring time
2. if however exists, check how many requests have been done ad if less than the limit allow the request and increment the number
3. if the limit has been exceeded, reject the request.

We can just use the current_minute in the key because we're expiring the keys and this means that while the hour is changing, between 59 and 00, it's not possible to have another 59, it would have been expired an hour before.

#### Add concurrency

This could be done using a number of configurable threads that pops their tasks from an internal TODO list represented with an array.
Each thread pops from the todo list and subsequently pops from Redis to perform the process.
In the `docs` folder there's a PDF with a diagram of a simple Thread pool architecture - It could have been done better, but I do not use Google Jamboard really often.


#### Allow custom crash statistics:

Not sure if I really understood the problem here but I will try:

The stats endpoint should be modified in such a way that allows passing some optional parameters and this could be done in this way:

1. GET `/stats/:projectId` as it is will give back the default stats
2. allowing the endpoint to accept a POST `stats/:projectId` with a body similar to this one:

```
{
  "metadata": {
    "subscription": [
      {
        "level": "pro_plan"
      },
      {
        "level": "basic"
      }
    ]
  }
}

{
  "metadata": {
    "query": {
      "stats": [
        {
          "type": "duration",
          "operator": ">",
          "value": 1000
        },
        {
          "type": "duration",
          "operator": "<",
          "value": 1000
        }
      ]
    }
  }
}
```  

In this case the contract with the client needs to be clear: if the payload has a subscription value, this value needs to be an array of objects that have a `level` key and a correspondent `value` so that we could search for different levels on the same projectId - eg: could have switched the plan and wanted to know stats for each plan.

Same for the second example, if the `query` key is present it must be an array of objects that each have a `type`, `operator`, `value`, to allow a proper search among the metadata.

On the other side the original payload needs to have that metadata in its payload (e.g. subscription level, or duration of queries) and the application needs to be changed allowing the custom metadata to be saved in a database alongside the original payload:

Original Stats Saved:

```
{
    "projectId": "1235",
    "invalid": 0,
    "error": 1,
    "info": 0,
    "warning": 2
}
```

New Version could be built up by using the custom metadata provided in the search payload:

```
{
  "projectId": "1235",
  "invalid": 0,
  "error": 1,
  "info": 0,
  "warning": 2,
  "metadata": {
    "subscription": [
      {
        "level": "pro_plan",
        "value": "some-value"
      }
    ]
  }
}
```
But as I said in the beginning I'm not sure I've completely got the specs.

### Take home key points

Although I planned the solution before starting coding and I wanted to do a test first approach, some of the choices I made in the beginning did not help at all - like using a background job and using clockwork - for two main reasons:

1. I did not have a deep knowledge of the tools - in particular Sinatra and Resque
2. I should have kept it simple from the beginning and going through different rounds of refactoring to both optimise and polish the code.

The take home test has been really interesting and underlined some key difficulties of managing something that, at a first glance appears to be simple but in the end has some difficulties linked to performance, simplicity of maintenance, concurrency etc.

In the end I'm not completely satisfied with the result of the test, but whatever the result will be I'm happy that I had a challenging task to solve, that made me think and took into account many different little things.
