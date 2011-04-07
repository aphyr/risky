Risky
=====

(Hey guys, I'll be porting over tests from our internal suite, and packaging Risky as a gem, in the next few evenings. --Kyle)

A simple, lightweight object layer for Riak.

    class User < Risky
      bucket :users
    end

    User.new('clu', 'fights' => 'for the users').save

    User['clu']['fights'] #=> 'for the users'

Built on top of seancribb's excellent riak-client, Risky provides basic
infrastructure for designing models with attributes (including defaults and
casting to/from JSON), validation, lifecycle callbacks, link-walking,
mapreduce, and more. Modules are available for timestamps, chronologically ordered lists, and basic secondary indexes.

Risky does not provide the rich API of Ripple, but it also does not require activesupport. It strives to be understandable, minimal, and modular. Magic is avoided in favor of module composition and a compact API.

Risky stores every instance of a model in a given bucket, indexed by key. Objects are stored as JSON hashes.

Show me the code!
-----------------

    class User < Risky
      include Risky::Indexes
      include Risky::Timestamps

      bucket :users

      # Provides user.name instead of user['name']
      value :name
      value :twitter, :default => {}

      # :class is used to cast times from JSON back into Time objects.
      value :updated_at, :class => Time
      value :created_at, :class => Time

      # Provides User.by_name. Changing the name stores an object in the
      # users_by_name bucket, with key user.name, linking back to us. A validate
      # function is used to ensure uniqueness before saving.
      index :name, :unique => true

      # Here, a custom proc returns the key used for the index.
      index :twitter_id, :proc => lambda { |user| user.twitter['id'] }

      # Provides user.followers, a list of links with the 'followers' tag.
      links :followers
    end

License
-------

Risky was developed by Kyle Kingsbury <aphyr@aphyr.com> at http://vodpod.com,
for their iPad social video app "Showyou". Generous thanks to Sean Cribbs, Mark
Phillips, the Basho team, and all the other #riak'ers. Released under the MIT
license.
