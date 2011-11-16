
module ACM::Models
  module Common

    def after_initialize
      @logger = ACM::Config.logger
    end

    def before_create
      super
      set_created_time
    end

    def set_created_time
      self.created_at = Time.now()
      self.last_updated_at = Time.now()
    end

    def before_update
      super
      @logger.debug("self.last_updated_at #{self.inspect}")
      self.last_updated_at = Time.now()
    end

    def latest_schema
      "urn:acm:schemas:1.0"
    end

  end
end