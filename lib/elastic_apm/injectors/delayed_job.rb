# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class DelayedJobInjector
      CLASS_SEPARATOR = '.'.freeze
      METHOD_SEPARATOR = '#'.freeze
      TYPE = 'Delayed::Job'.freeze

      def install
        ::Delayed::Backend::Base.class_eval do
          alias invoke_job_without_apm invoke_job

          def invoke_job(*args, &block)
            ::ElasticAPM::Injectors::DelayedJobInjector
              .invoke_job(self, *args, &block)
          end
        end
      end

      def self.invoke_job(job, *args, &block)
        job_name = name_from_payload(job.payload_object)
        transaction = ElasticAPM.transaction(job_name, TYPE)
        job.invoke_job_without_apm(*args, &block)
        transaction.submit 'success'
      rescue ::Exception => e
        ElasticAPM.report(e, handled: false)
        transaction.submit 'error'
        raise
      ensure
        transaction.release if transaction
      end

      def self.name_from_payload(payload_object)
        if payload_object.is_a?(::Delayed::PerformableMethod)
          performable_method_name(payload_object)
        else
          payload_object.class.name
        end
      end

      def self.performable_method_name(payload_object)
        class_name = object_name(payload_object)
        separator = name_separator(payload_object)
        method_name = payload_object.method_name
        "#{class_name}#{separator}#{method_name}"
      end

      def self.object_name(payload_object)
        object = payload_object.object
        klass = object.is_a?(Class) ? object : object.class
        klass.name
      end

      def self.name_separator(payload_object)
        payload_object.object.is_a?(Class) ? CLASS_SEPARATOR : METHOD_SEPARATOR
      end
    end

    register(
      'Delayed::Backend::Base',
      'delayed/backend/base',
      DelayedJobInjector.new
    )
  end
end
