# frozen_string_literal: true

module ElasticAPM
  class Context
    # @api private
    class User
      def initialize(id: nil, email: nil, username: nil)
        @id = id
        @email = email
        @username = username
      end

      def self.infer(config, record)
        return unless record

        new(
          id: safe_get(record, config.current_user_id_method)&.to_s,
          email: safe_get(record, config.current_user_email_method),
          username: safe_get(record, config.current_user_username_method)
        )
      end

      attr_accessor :id, :email, :username

      def empty?
        !id && !email && !username
      end

      class << self
        private

        def safe_get(record, method_name)
          record.respond_to?(method_name) ? record.send(method_name) : nil
        end
      end
    end
  end
end
