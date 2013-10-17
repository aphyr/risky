module Risky::GZip
  require 'zlib'

  GZIP_CONTENT_TYPE = 'application/x-gzip'

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def content_type
      GZIP_CONTENT_TYPE
    end
  end

  module GZipSerializer
    def self.dump(*args)
      Zlib::Deflate.deflate MultiJson.dump(*args)
    end

    def self.load(*args)
      MultiJson.load(Zlib::Inflate.inflate *args)
    end
  end

  Riak::Serializers[GZIP_CONTENT_TYPE] = GZipSerializer

end