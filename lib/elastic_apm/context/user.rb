# frozen_string_literal: true

module ElasticAPM
  class Context
    # @api private
    class User
      include NaivelyHashable

      def initialize(config, record)
        return unless record

        @id = safe_get(record, config.current_user_id_method)
        @email = safe_get(record, config.current_user_email_method)
        @username = safe_get(record, config.current_user_username_method)
      end

      attr_accessor :id, :email, :username

      private

      def safe_get(record, method_name)
        record.respond_to?(method_name) ? record.send(method_name) : nil
      end
    end
  end
end
