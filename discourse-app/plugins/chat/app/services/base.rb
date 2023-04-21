# frozen_string_literal: true

module Chat
  module Service
    # Module to be included to provide steps DSL to any class. This allows to
    # create easy to understand services as the whole service cycle is visible
    # simply by reading the beginning of its class.
    #
    # Steps are executed in the order they’re defined. They will use their name
    # to execute the corresponding method defined in the service class.
    #
    # Currently, there are 5 types of steps:
    #
    # * +contract(name = :default)+: used to validate the input parameters,
    #   typically provided by a user calling an endpoint. A special embedded
    #   +Contract+ class has to be defined to holds the validations. If the
    #   validations fail, the step will fail. Otherwise, the resulting contract
    #   will be available in +context[:contract]+. When calling +step(name)+ or
    #   +model(name = :model)+ methods after validating a contract, the contract
    #   should be used as an argument instead of context attributes.
    # * +model(name = :model)+: used to instantiate a model (either by building
    #   it or fetching it from the DB). If a falsy value is returned, then the
    #   step will fail. Otherwise the resulting object will be assigned in
    #   +context[name]+ (+context[:model]+ by default).
    # * +policy(name = :default)+: used to perform a check on the state of the
    #   system. Typically used to run guardians. If a falsy value is returned,
    #   the step will fail.
    # * +step(name)+: used to run small snippets of arbitrary code. The step
    #   doesn’t care about its return value, so to mark the service as failed,
    #   {#fail!} has to be called explicitly.
    # * +transaction+: used to wrap other steps inside a DB transaction.
    #
    # The methods defined on the service are automatically provided with
    # the whole context passed as keyword arguments. This allows to define in a
    # very explicit way what dependencies are used by the method. If for
    # whatever reason a key isn’t found in the current context, then Ruby will
    # raise an exception when the method is called.
    #
    # Regarding contract classes, they automatically have {ActiveModel} modules
    # included so all the {ActiveModel} API is available.
    #
    # @example An example from the {TrashChannel} service
    #   class TrashChannel
    #     include Base
    #
    #     model :channel, :fetch_channel
    #     policy :invalid_access
    #     transaction do
    #       step :prevents_slug_collision
    #       step :soft_delete_channel
    #       step :log_channel_deletion
    #     end
    #     step :enqueue_delete_channel_relations_job
    #
    #     private
    #
    #     def fetch_channel(channel_id:, **)
    #       ChatChannel.find_by(id: channel_id)
    #     end
    #
    #     def invalid_access(guardian:, channel:, **)
    #       guardian.can_preview_chat_channel?(channel) && guardian.can_delete_chat_channel?
    #     end
    #
    #     def prevents_slug_collision(channel:, **)
    #       …
    #     end
    #
    #     def soft_delete_channel(guardian:, channel:, **)
    #       …
    #     end
    #
    #     def log_channel_deletion(guardian:, channel:, **)
    #       …
    #     end
    #
    #     def enqueue_delete_channel_relations_job(channel:, **)
    #       …
    #     end
    #   end
    # @example An example from the {UpdateChannelStatus} service which uses a contract
    #   class UpdateChannelStatus
    #     include Base
    #
    #     model :channel, :fetch_channel
    #     contract
    #     policy :check_channel_permission
    #     step :change_status
    #
    #     class Contract
    #       attribute :status
    #       validates :status, inclusion: { in: ChatChannel.editable_statuses.keys }
    #     end
    #
    #     …
    #   end
    module Base
      extend ActiveSupport::Concern

      # The only exception that can be raised by a service.
      class Failure < StandardError
        # @return [Context]
        attr_reader :context

        # @!visibility private
        def initialize(context = nil)
          @context = context
          super
        end
      end

      # Simple structure to hold the context of the service during its whole lifecycle.
      class Context < OpenStruct
        # @return [Boolean] returns +true+ if the conext is set as successful (default)
        def success?
          !failure?
        end

        # @return [Boolean] returns +true+ if the context is set as failed
        # @see #fail!
        # @see #fail
        def failure?
          @failure || false
        end

        # Marks the context as failed.
        # @param context [Hash, Context] the context to merge into the current one
        # @example
        #   context.fail!("failure": "something went wrong")
        # @return [Context]
        def fail!(context = {})
          fail(context)
          raise Failure, self
        end

        # Marks the context as failed without raising an exception.
        # @param context [Hash, Context] the context to merge into the current one
        # @example
        #   context.fail("failure": "something went wrong")
        # @return [Context]
        def fail(context = {})
          merge(context)
          @failure = true
          self
        end

        # Merges the given context into the current one.
        # @!visibility private
        def merge(other_context = {})
          other_context.each { |key, value| self[key.to_sym] = value }
          self
        end

        private

        def self.build(context = {})
          self === context ? context : new(context)
        end
      end

      # Internal module to define available steps as DSL
      # @!visibility private
      module StepsHelpers
        def model(name = :model, step_name = :"fetch_#{name}")
          steps << ModelStep.new(name, step_name)
        end

        def contract(name = :default, class_name: self::Contract, default_values_from: nil)
          steps << ContractStep.new(
            name,
            class_name: class_name,
            default_values_from: default_values_from,
          )
        end

        def policy(name = :default)
          steps << PolicyStep.new(name)
        end

        def step(name)
          steps << Step.new(name)
        end

        def transaction(&block)
          steps << TransactionStep.new(&block)
        end
      end

      # @!visibility private
      class Step
        attr_reader :name, :method_name, :class_name

        def initialize(name, method_name = name, class_name: nil)
          @name = name
          @method_name = method_name
          @class_name = class_name
        end

        def call(instance, context)
          method = instance.method(method_name)
          args = {}
          args = context.to_h if method.arity.nonzero?
          context[result_key] = Context.build
          instance.instance_exec(**args, &method)
        end

        private

        def type
          self.class.name.split("::").last.downcase.sub(/^(\w+)step$/, "\\1")
        end

        def result_key
          "result.#{type}.#{name}"
        end
      end

      # @!visibility private
      class ModelStep < Step
        def call(instance, context)
          context[name] = super
          raise ArgumentError, "Model not found" if context[name].blank?
        rescue ArgumentError => exception
          context[result_key].fail(exception: exception)
          context.fail!
        end
      end

      # @!visibility private
      class PolicyStep < Step
        def call(instance, context)
          if !super
            context[result_key].fail
            context.fail!
          end
        end
      end

      # @!visibility private
      class ContractStep < Step
        attr_reader :default_values_from

        def initialize(name, method_name = name, class_name: nil, default_values_from: nil)
          super(name, method_name, class_name: class_name)
          @default_values_from = default_values_from
        end

        def call(instance, context)
          attributes = class_name.attribute_names.map(&:to_sym)
          default_values = {}
          default_values = context[default_values_from].slice(*attributes) if default_values_from
          contract = class_name.new(default_values.merge(context.to_h.slice(*attributes)))
          context[contract_name] = contract
          context[result_key] = Context.build
          if contract.invalid?
            context[result_key].fail(errors: contract.errors)
            context.fail!
          end
        end

        private

        def contract_name
          return :contract if name.to_sym == :default
          :"#{name}_contract"
        end
      end

      # @!visibility private
      class TransactionStep < Step
        include StepsHelpers

        attr_reader :steps

        def initialize(&block)
          @steps = []
          instance_exec(&block)
        end

        def call(instance, context)
          ActiveRecord::Base.transaction { steps.each { |step| step.call(instance, context) } }
        end
      end

      included do
        # The global context which is available from any step.
        attr_reader :context

        # @!visibility private
        # Internal class used to setup the base contract of the service.
        self::Contract =
          Class.new do
            include ActiveModel::API
            include ActiveModel::Attributes
            include ActiveModel::AttributeMethods
            include ActiveModel::Validations::Callbacks
          end
      end

      class_methods do
        include StepsHelpers

        def call(context = {})
          new(context).tap(&:run).context
        end

        def call!(context = {})
          new(context).tap(&:run!).context
        end

        def steps
          @steps ||= []
        end
      end

      # @!scope class
      # @!method model(name = :model, step_name = :"fetch_#{name}")
      # @param name [Symbol] name of the model
      # @param step_name [Symbol] name of the method to call for this step
      # Evaluates arbitrary code to build or fetch a model (typically from the
      # DB). If the step returns a falsy value, then the step will fail.
      #
      # It stores the resulting model in +context[:model]+ by default (can be
      # customized by providing the +name+ argument).
      #
      # @example
      #   model :channel, :fetch_channel
      #
      #   private
      #
      #   def fetch_channel(channel_id:, **)
      #     ChatChannel.find_by(id: channel_id)
      #   end

      # @!scope class
      # @!method policy(name = :default)
      # @param name [Symbol] name for this policy
      # Performs checks related to the state of the system. If the
      # step doesn’t return a truthy value, then the policy will fail.
      #
      # @example
      #   policy :no_direct_message_channel
      #
      #   private
      #
      #   def no_direct_message_channel(channel:, **)
      #     !channel.direct_message_channel?
      #   end

      # @!scope class
      # @!method contract(name = :default, class_name: self::Contract, default_values_from: nil)
      # @param name [Symbol] name for this contract
      # @param class_name [Class] a class defining the contract
      # @param default_values_from [Symbol] name of the model to get default values from
      # Checks the validity of the input parameters.
      # Implements ActiveModel::Validations and ActiveModel::Attributes.
      #
      # It stores the resulting contract in +context[:contract]+ by default
      # (can be customized by providing the +name+ argument).
      #
      # @example
      #   contract
      #
      #   class Contract
      #     attribute :name
      #     validates :name, presence: true
      #   end

      # @!scope class
      # @!method step(name)
      # @param name [Symbol] the name of this step
      # Runs arbitrary code. To mark a step as failed, a call to {#fail!} needs
      # to be made explicitly.
      #
      # @example
      #   step :update_channel
      #
      #   private
      #
      #   def update_channel(channel:, params_to_edit:, **)
      #     channel.update!(params_to_edit)
      #   end
      # @example using {#fail!} in a step
      #   step :save_channel
      #
      #   private
      #
      #   def save_channel(channel:, **)
      #     fail!("something went wrong") if !channel.save
      #   end

      # @!scope class
      # @!method transaction(&block)
      # @param block [Proc] a block containing steps to be run inside a transaction
      # Runs steps inside a DB transaction.
      #
      # @example
      #   transaction do
      #     step :prevents_slug_collision
      #     step :soft_delete_channel
      #     step :log_channel_deletion
      #   end

      # @!visibility private
      def initialize(initial_context = {})
        @initial_context = initial_context.with_indifferent_access
        @context = Context.build(initial_context.merge(__steps__: self.class.steps))
      end

      # @!visibility private
      def run
        run!
      rescue Failure => exception
        raise if context.object_id != exception.context.object_id
      end

      # @!visibility private
      def run!
        self.class.steps.each { |step| step.call(self, context) }
      end

      # @!visibility private
      def fail!(message)
        step_name = caller_locations(1, 1)[0].label
        context["result.step.#{step_name}"].fail(error: message)
        context.fail!
      end
    end
  end
end
