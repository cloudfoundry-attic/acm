
module ACM::Services

  class ACMService

    def initialize
      @logger = ACM::Config.logger

    end

    def get_option(map, key)
      map[key].nil? ? nil : map[key]
    end

  end

end
