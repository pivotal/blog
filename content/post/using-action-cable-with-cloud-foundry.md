---
authors:
- dgriffith
categories:
- Ruby On Rails
- Cloud Foundry
date: 2016-07-24T13:27:26+10:00
draft: false
short: |
  A guide to configuring and deploying a Rails 5 Action Cable app to Cloud Foundry.
title: Using Action Cable With Cloud Foundry
---

## About This Guide
This post is going to show you how to set up a Rails 5 app that makes use of the new [Action Cable](https://github.com/rails/rails/tree/master/actioncable) feature to perform live reloads of part of a web page. Action Cable is based on Websockets and is one of the new features just released with Rails 5. This new library gives you the ability to easily create real time web applications without pulling in any third party gems to handle the websockets. Additionally the integration with other rails components and conventions means you can write very few lines of code to accomplish a great deal (this is why we use rails in the first place).

As well as showing you the basics of Action Cable this guide will show you how to configure your app so that it runs on Cloud Foundry. In this particular guide we will be deploying to [PWS](https://run.pivotal.io/), which is Pivotal's consumer instance of Cloud Foundry, however most of the steps will be relevant to any Cloud Foundry instance.

All code used here can be found [here](https://github.com/pivotal-sydney/action-cable-test).

Here is a demo of the running app syncing messages across tabs using websockets:
{{< responsive-figure src="https://camo.githubusercontent.com/2aaf8beb1524062bbc58d4324b7aac141d960433/687474703a2f2f672e7265636f726469742e636f2f6b6e6e74444f335074642e676966" >}}

## Setting Up The Application

Firstly we create a new rails application the usual way with the rails 5.X.X gem installed:

~~~bash
rails new action-cable-test
~~~

### Adding The Models
We want our app to display a live list of messages so our model is just:

~~~ruby
# app/models/message.rb
class Message < ApplicationRecord
end
~~~

And the migration is:

~~~ruby
class CreateMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :messages do |t|
      t.text :message
      t.timestamps
    end
  end
end
~~~

### Adding The Front End

Now that we have a our model we want a view to create and show them. For now it will be a single input form and a list of messages underneath.

We must first add our routes to `config/routes.rb`.
~~~ruby
Rails.application.routes.draw do
  root to: redirect('/messages')
  resources :messages, only: [:index, :create]
end
~~~

Then we must add the `app/controllers/messages_controller.rb`:
~~~ruby
class MessagesController < ApplicationController
  def index
    @messages = Message.all
  end

  def create
    @message = Message.create!(params.require(:message).permit(:message))

    redirect_to messages_url
  end
end
~~~

And now the views:

~~~ruby
# app/views/messages/index.html.erb
<%= form_for Message.new do |f| %>
  <%= f.text_field :message %>
<%= f.submit %>
<% end %>
<div id="messages">
  <%= render 'message_list', messages: @messages %>
</div>
~~~

~~~ruby
# app/views/messages/_message_list.html.erb
<ul>
  <% messages.each do |message| %>
    <li><%= message.message %></li>
  <% end %>
</ul>
~~~

The reason we've split up the list into a separate view will become clearer in the next section.

## Making It Real Time!
Ok so at this point we have our app set up with a form and a list of messages but the problem is that we don't have the messages live updating when we have multiple clients with the page open simultaneously. In order to accomplish this we are going to use the new [Action Cable](https://github.com/rails/rails/tree/master/actioncable) feature in Rails 5.

### Setting Up The Channel

Rails 5 comes with a generator to set up some of the boiler plate for your Action Cable channel:

~~~bash
$ bin/rails generate channel messages
create app/channels/messages_channel.rb
create  app/assets/javascripts/cable.js
create  app/assets/javascripts/channels/messages.coffee
~~~

#### The Channel
The first generated file we're going to change is `app/channels/messages_channel.rb` which is the backend code. The `MessagesChannel` is a bit like a rails controller but for Action Cable.

We are going to make a couple of changes to this file.
~~~ruby
class MessagesChannel < ApplicationCable::Channel
  def self.broadcast
    broadcast_to "messages",
      messages: MessagesController.render(
        partial: 'messages/message_list',
        locals: { messages: Message.all }
    )
  end

  def subscribed
    stream_from "messages:messages"
  end

  def unsubscribed
  end
end
~~~

The first change is the `self.broadcast` method. This is a helper we're going to call later in order broadcast changes to the messages list. As you can see this renders the `app/views/messages/_message_list.html.erb` partial and broadcasts this to all subscribers of `"messages"`. Since this is the `MessagesChannel` this then becomes the `"messages:messages"` in the subscribed method.

The other change is to the `subscribed` method. Here we add `stream_from "messages:messages"` so that all subscribers are set up to stream from the `"messages:messages"` topic.

#### The Controller
Now that we have a helper to broadcast changes we need to call this whenever our messages list updates. To do this we add call to `MessagesChannel.broadcast` in `app/controllers/messages_controller.rb`:
~~~ruby
class MessagesController < ApplicationController
  def index
    @messages = Message.all
  end

  def create
    Message.create!(params.require(:message).permit(:message))

    # Broadcast must be done after creating the new message so it's
    # there when we render the template.
    MessagesChannel.broadcast

    redirect_to messages_url
  end
end
~~~

#### The Javascript
Now we have the messages list being broadcast to all subscribers whenever there is a change, but we aren't doing anything with these messages yet. To ensure the changes are reflected live on the page we add a little bit of code to our `app/assets/javascripts/channels/messages.coffee`.

~~~coffeescript
App.messages = App.cable.subscriptions.create "MessagesChannel",
  connected: ->

  disconnected: ->

  received: (data) ->
    $('#messages').html(data.messages)
~~~

This snippet of jquery simply finds the existing messages list and swaps it out with the new messages list html that we sent via the websockets payload.

And that's really it for the Action Cable stuff. If we now open two browsers locally on the app we'll be able to see our changes synchronised across both browsers without even refreshing. It's also pretty quick, too.

Now that we have our messages app up and running locally we need to ship it to production!

### Deploying To Cloud Foundry

#### CF Services
In development we were just using an in memory async process for communicating with our websocket subscribers, but for production we need something externalized if we want to be able to run multiple instances of the application.

Action Cable by default uses Redis for publishing/subscribing changes in the production environment. The good news for us is that we already have a Redis tile on PWS that we can easily install. Additionally we are going to want add a database to our application for production. For that we'll use Postgres. We can set these services up easily using the [CF CLI](https://github.com/cloudfoundry/cli):

~~~bash
$ cf create-service rediscloud 30mb redis-actioncable && cf create-service elephantsql turtle postgres-actioncable
Creating service instance redis-actioncable in org myorg / space development as me@example.com...
OK
Creating service instance postgres-actioncable in org myorg / space development as me@example.com...
OK
~~~

Now that we've created our services we can bind them in our `manifest.yml`. Mine looks like:

~~~yaml

---
applications:
  - name: actioncable
    memory: 128M
    command: bundle exec rake db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
    services:
      - postgres-actioncable
      - redis-actioncable
~~~

#### Configuring Action Cable

Since the defaults for Action Cable in Rails 5 are not quite right for PWS we'll need to configure a couple of things differently. Firstly we need some gems for production dependencies and configuration. We should add the following to our `Gemfile`:

~~~ruby
group :production do
  # Used for extracting data from CF environment
  gem 'cf-app-utils'
  gem 'addressable'

  gem 'redis'
  gem 'pg'
end
~~~

Be sure to run `bundle install` before deploying.

The default `cable.yml` chooses to configure Redis using a single url parameter which we must construct from our CF credentials. We can connect to our CF Redis service if we update `config/cable.yml` to the following:

~~~yaml
development:
  adapter: async

test:
  adapter: async

production:
  adapter: redis
  url: <%= ENV["RAILS_ENV"] == "production" && (c = CF::App::Credentials.find_by_service_tag('redis')) && Addressable::URI.new(scheme: 'redis', host: c.fetch('hostname'), password: c.fetch('password'), port: c.fetch('port')).to_s %>
~~~

Since PWS uses port 4443 (rather than 443) for websocket connections we need to make a small change to our `config/environments/production.rb`. To configure this port we add the following lines in the configure block:

~~~ruby
application_uris = JSON.parse(ENV['VCAP_APPLICATION'])['application_uris']

# Be sure this host is able to route your requests on port 4443. This can be an
# issue if you have a proxy in front of your application that will not proxy port
# 4443 (eg. CloudFlare).
first_host = application_uris[0]
config.action_cable.url = "wss://#{first_host}:4443/cable"

config.action_cable.allowed_request_origins = application_uris.flat_map { |host| ["http://#{host}", "https://#{host}"] }
~~~

The last bit of configuration is to update the javascript to use port 4443 rather than the default 443. In order to not hardcode anything in the JS we add a snippet to `app/views/layouts/application.html.erb` to pass the url to the frontend like so:

~~~diff
<!DOCTYPE html>
 <html>
   <head>
+    <script type="text/javascript">window.action_cable_url = '<%= Rails.configuration.action_cable.url %>'</script>
     <title>ActionCableTest</title>
~~~

Then we must update the `app/assets/javascripts/cable.js` to read this global variable before making the connection:

~~~diff
 (function() {
   this.App || (this.App = {});

-  App.cable = ActionCable.createConsumer();
+  if(window.action_cable_url) {
+    App.cable = ActionCable.createConsumer(window.action_cable_url);
+  } else {
+    App.cable = ActionCable.createConsumer();
+  }

 }).call(this);
~~~

Now that we've got the configuration out of the way we can deploy to production with an easy `cf push`.

## In Summary

We were able to use the new [Action Cable](https://github.com/rails/rails/tree/master/actioncable) feature in Rails 5 to make a real time web app and then integrate that easily into Cloud Foundry using the Redis and Postgres services.

## Some Asides

Action Cable [does appear to support using Postgres for the pub/sub](https://github.com/rails/rails/tree/52ce6ece8c8f74064bb64e0a0b1ddd83092718e1/actioncable/lib/action_cable/subscription_adapter) (rather than Redis) so we could have in theory avoided using two different services for this app but as Redis was the default and since it's such a commonly used service it made sense for choosing that in the example.
