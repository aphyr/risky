require 'spec_helper'

class Album < Risky
  include Risky::ListKeys
  include Risky::SecondaryIndexes

  bucket :risky_albums
  allow_mult
  index2i :artist_id, :map => true
  index2i :label_key, :map => '_key', :finder => :find_by_id, :allow_nil => true
  index2i :genre, :type => :bin, :allow_nil => true
  index2i :tags, :type => :bin, :multi => true, :allow_nil => true
  value :name
  value :year
end

class Artist < Risky
  include Risky::ListKeys

  bucket :risky_artists
  value :name
end

class Label < Risky
  include Risky::ListKeys

  bucket :risky_labels
  value :name

  def self.find_by_id(id)
    find(id)
  end
end

class City < Risky
  include Risky::SecondaryIndexes

  bucket :risky_cities
  index2i :country_id, :type => :invalid, :allow_nil => true
  value :name
  value :details
end


describe Risky::SecondaryIndexes do
  let(:artist) { Artist.create(1, :name => 'Motorhead') }
  let(:label) { Label.create(1, :name => 'Bronze Records') }

  before :each do
    Album.delete_all
    Artist.delete_all
    Label.delete_all
  end

  it "sets indexes on initialize" do
    album = Album.new(1, {:name => 'Bomber', :year => 1979}, {:artist_id => 2})
    album.indexes2i.should == {"artist_id" => 2 }
  end

  it "defines getter and setter methods" do
    album = Album.new(1)
    album.artist_id = 1
    album.artist_id.should == 1
  end

  it "defines association getter and setter methods" do
    album = Album.new(1)
    album.artist = artist
    album.artist.should == artist
  end

  it "defines association getter and setter methods when using suffix" do
    album = Album.new(1)
    album.label = label
    album.label.should == label
  end

  it "can use a custom finder" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})

    Label.should_receive(:find_by_id).with(label.id).and_return(label)

    album.label.should == label
  end

  it "resets association if associated object is not saved" do
    artist = Artist.new('new_key')
    album = Album.new('new_key')
    album.artist = artist
    album.artist.should be_nil
  end

  it "assigns attributs after association assignment" do
    album = Album.new(1)
    album.artist = artist
    album.artist_id.should == artist.id
  end

  it "assigns association after attribute assignment" do
    album = Album.new(1)
    album.artist_id = artist.id
    album.artist.should == artist
  end

  it "saves a model with indexes" do
    album = Album.new(1, {:name => 'Ace of Spades' }, { :artist_id => 1 }).save
    album.artist_id.should == 1
  end

  it "creates a model with indexes" do
    album = Album.create(1, {:name => 'Ace of Spades' }, { :artist_id => 1 })
    album.artist_id.should == 1
  end

  it "persists association after save" do
    album = Album.new('persist_key')
    album.name = 'Ace of Spades'
    album.artist_id = artist.id
    album.save

    album.artist.should == artist
    album.artist_id.should == artist.id

    album.reload

    album.artist.should == artist
    album.artist_id.should == artist.id

    album = Album.find(album.key)

    album.artist.should == artist
    album.artist_id.should == artist.id
  end

  it "finds first by int secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id})

    albums = Album.find_by_index(:artist_id, artist.id)
    albums.should == album
  end

  it "finds all by int secondary index" do
    album1 = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})
    album2 = Album.create(2, {:name => 'Ace Of Spaces', :year => 1980},
      {:artist_id => artist.id, :label_key => label.id})

    albums = Album.find_all_by_index(:artist_id, artist.id)
    albums.should include(album1)
    albums.should include(album2)
  end

  it "finds all by binary secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id, :genre => 'heavy'})

    Album.find_all_by_index(:genre, 'heavy').should == [album]
  end

  it "finds all by multi binary secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id,
       :tags => ['rock', 'heavy']})

    Album.find_all_by_index(:tags, 'heavy').should == [album]
    Album.find_all_by_index(:tags, 'rock').should == [album]
  end

  it "paginates keys" do
    album1 = Album.create('1', {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})
    album2 = Album.create('2', {:name => 'Ace Of Spaces', :year => 1980},
      {:artist_id => artist.id, :label_key => label.id})
    album3 = Album.create('3', {:name => 'Overkill', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})

    page1 = Album.paginate_keys_by_index(:artist_id, artist.id, :max_results => 2)
    page1.should == ['1', '2']
    page1.continuation.should_not be_blank

    page2 = Album.paginate_keys_by_index(:artist_id, artist.id, :max_results => 2, :continuation => page1.continuation)
    page2.should == ['3']
    page2.continuation.should be_blank
  end

  it "paginates risky objects" do
    album1 = Album.create('1', {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})
    album2 = Album.create('2', {:name => 'Ace Of Spaces', :year => 1980},
      {:artist_id => artist.id, :label_key => label.id})
    album3 = Album.create('3', {:name => 'Overkill', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})

    page1 = Album.paginate_by_index(:artist_id, artist.id, :max_results => 2)
    page1.should == [album1, album2]
    page1.continuation.should_not be_blank

    page2 = Album.paginate_by_index(:artist_id, artist.id, :max_results => 2, :continuation => page1.continuation)
    page2.should == [album3]
    page2.continuation.should be_blank
  end

  it "raises an exception when index is nil" do
    album = Album.new(1)
    expect { album.save }.to raise_error(ArgumentError)
  end

  it "raises an exception when type is invalid" do
    city = City.new(1)
    expect { city.save }.to raise_error(TypeError)
  end

  it "can inspect a model" do
    album = Album.new(1, { :name => 'Bomber' }, { :artist_id => 2 })

    album.inspect.should match(/Album 1/)
    album.inspect.should match(/"name"=>"Bomber"/)
    album.inspect.should match(/"artist_id"=>2/)
  end
end
